/// Low-level FFI bindings to llama.cpp shared library.
///
/// When the native library is available, this calls directly into llama.cpp.
/// When unavailable (development / testing), a mock implementation provides
/// realistic sample responses so the rest of the app can run normally.
///
/// Uses only `dart:ffi` — no external FFI helper packages required.
library;

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

// ---------------------------------------------------------------------------
// Native function typedefs
//
// We use Pointer<Uint8> for `const char*` because the `Utf8` type lives in
// `package:ffi` which is not in our dependency list. In the real native path
// we manually encode/decode UTF-8 bytes through these opaque pointers.
// ---------------------------------------------------------------------------

// C: void* llama_init(const char* model_path)
typedef _LlamaInitNative = Pointer<Void> Function(Pointer<Uint8>);
typedef _LlamaInitDart = Pointer<Void> Function(Pointer<Uint8>);

// C: const char* llama_generate(void* ctx, const char* prompt, int max_tokens)
typedef _LlamaGenerateNative = Pointer<Uint8> Function(
    Pointer<Void>, Pointer<Uint8>, Int32);
typedef _LlamaGenerateDart = Pointer<Uint8> Function(
    Pointer<Void>, Pointer<Uint8>, int);

// C: void llama_dispose(void* ctx)
typedef _LlamaDisposeNative = Void Function(Pointer<Void>);
typedef _LlamaDisposeDart = void Function(Pointer<Void>);

// C: void llama_free_string(const char* str)
typedef _LlamaFreeStringNative = Void Function(Pointer<Uint8>);
typedef _LlamaFreeStringDart = void Function(Pointer<Uint8>);

// ---------------------------------------------------------------------------
// LlamaFfi — wraps the native library or falls back to mock
// ---------------------------------------------------------------------------

/// Interface to llama.cpp engine.
///
/// Call [init] to load the model, [generate] to produce text, and [dispose]
/// to release resources. If the native shared library is not found, all
/// operations transparently fall back to a mock that returns plausible JSON.
class LlamaFfi {
  bool _initialized = false;
  bool _useMock = false;
  DynamicLibrary? _lib;
  Pointer<Void>? _ctx;
  _LlamaGenerateDart? _generateFn;
  _LlamaDisposeDart? _disposeFn;
  _LlamaFreeStringDart? _freeStringFn;

  /// Whether the model (or mock) is currently loaded.
  bool get isInitialized => _initialized;

  /// Whether we are running with the mock fallback (no native library).
  bool get isMock => _useMock;

  /// Load the model from [modelPath].
  ///
  /// If the native shared library cannot be found, switches to mock mode
  /// automatically — the caller does not need to handle this case.
  Future<void> init(String modelPath) async {
    if (_initialized) return;

    try {
      _lib = _openLibrary();
      final initFn =
          _lib!.lookupFunction<_LlamaInitNative, _LlamaInitDart>('llama_init');
      _generateFn = _lib!
          .lookupFunction<_LlamaGenerateNative, _LlamaGenerateDart>(
              'llama_generate');
      _disposeFn = _lib!
          .lookupFunction<_LlamaDisposeNative, _LlamaDisposeDart>(
              'llama_dispose');
      // Optional: if the native lib provides a free function for returned strings
      try {
        _freeStringFn = _lib!
            .lookupFunction<_LlamaFreeStringNative, _LlamaFreeStringDart>(
                'llama_free_string');
      } catch (_) {
        _freeStringFn = null;
      }

      final pathPtr = _toNativeString(modelPath);
      _ctx = initFn(pathPtr);
      _freeNativeString(pathPtr);

      _useMock = false;
    } catch (_) {
      // Native library not available — fall back to mock
      _useMock = true;
    }

    _initialized = true;
  }

  /// Generate text from [prompt], producing at most [maxTokens] tokens.
  ///
  /// Returns the raw model output as a string.
  Future<String> generate(String prompt, {int maxTokens = 256}) async {
    if (!_initialized) {
      throw StateError('LlamaFfi not initialized. Call init() first.');
    }

    if (_useMock) {
      return _mockGenerate(prompt);
    }

    final promptPtr = _toNativeString(prompt);
    final resultPtr = _generateFn!(_ctx!, promptPtr, maxTokens);
    _freeNativeString(promptPtr);

    final result = _fromNativeString(resultPtr);
    if (_freeStringFn != null) {
      _freeStringFn!(resultPtr);
    }
    return result;
  }

  /// Release model resources.
  void dispose() {
    if (!_initialized) return;

    if (!_useMock && _disposeFn != null && _ctx != null) {
      try {
        _disposeFn!(_ctx!);
      } catch (e) {
        // FFI dispose may fail if native context is already freed
        // Log but don't rethrow — cleanup must continue
        assert(() { print('LlamaFfi.dispose() error: $e'); return true; }());
      }
    }

    _ctx = null;
    _lib = null;
    _generateFn = null;
    _disposeFn = null;
    _freeStringFn = null;
    _initialized = false;
  }

  // -------------------------------------------------------------------------
  // Native string helpers (only used in non-mock path)
  //
  // Uses C stdlib malloc/free via DynamicLibrary.process() so we don't
  // depend on package:ffi. These methods are only called when the real
  // native library is loaded.
  // -------------------------------------------------------------------------

  // C: void* malloc(size_t size)
  static final _malloc = DynamicLibrary.process()
      .lookupFunction<Pointer<Uint8> Function(IntPtr),
          Pointer<Uint8> Function(int)>('malloc');

  // C: void free(void* ptr)
  static final _free = DynamicLibrary.process()
      .lookupFunction<Void Function(Pointer<Uint8>),
          void Function(Pointer<Uint8>)>('free');

  /// Allocate a null-terminated UTF-8 string in native memory.
  static Pointer<Uint8> _toNativeString(String s) {
    final units = utf8.encode(s);
    final ptr = _malloc(units.length + 1);
    for (var i = 0; i < units.length; i++) {
      ptr[i] = units[i];
    }
    ptr[units.length] = 0; // null terminator
    return ptr;
  }

  /// Read a null-terminated UTF-8 string from native memory.
  static String _fromNativeString(Pointer<Uint8> ptr) {
    if (ptr == nullptr) return '';
    final bytes = <int>[];
    var i = 0;
    while (true) {
      final byte = ptr[i];
      if (byte == 0) break;
      bytes.add(byte);
      i++;
    }
    return utf8.decode(bytes);
  }

  /// Free a native string allocated by [_toNativeString].
  static void _freeNativeString(Pointer<Uint8> ptr) {
    _free(ptr);
  }

  // -------------------------------------------------------------------------
  // Platform-specific library loading
  // -------------------------------------------------------------------------

  static DynamicLibrary _openLibrary() {
    if (Platform.isIOS) {
      return DynamicLibrary.process();
    }

    final String libName;
    if (Platform.isAndroid || Platform.isLinux) {
      libName = 'libllama.so';
    } else if (Platform.isMacOS) {
      libName = 'libllama.dylib';
    } else if (Platform.isWindows) {
      libName = 'llama.dll';
    } else {
      throw UnsupportedError(
          'Unsupported platform: ${Platform.operatingSystem}');
    }

    // Try bundled path first, then system path
    final bundled = p.join(Directory.current.path, 'native', libName);
    if (File(bundled).existsSync()) {
      return DynamicLibrary.open(bundled);
    }

    return DynamicLibrary.open(libName);
  }

  // -------------------------------------------------------------------------
  // Mock implementation — returns realistic JSON for each prompt type
  // -------------------------------------------------------------------------

  static final _random = Random();

  static Future<String> _mockGenerate(String prompt) async {
    // Simulate latency (~200-500ms)
    await Future<void>.delayed(
      Duration(milliseconds: 200 + _random.nextInt(300)),
    );

    if (prompt.contains('"tags"') || prompt.contains('Extract')) {
      return _mockTagResponse();
    }
    if (prompt.contains('"category"') || prompt.contains('Classify')) {
      return _mockClassifyResponse();
    }
    if (prompt.contains('"connections"') || prompt.contains('related notes')) {
      return _mockConnectionResponse(prompt);
    }

    // Generic fallback
    return '{"result": "mock response"}';
  }

  static String _mockTagResponse() {
    const tagPool = [
      'flutter',
      'dart',
      'programming',
      'design',
      'architecture',
      'mobile',
      'ui',
      'database',
      'notes',
      'productivity',
      'learning',
      'project',
      'idea',
      'reference',
      'tutorial',
      'api',
      'testing',
      'devops',
      'security',
      'performance',
    ];

    // Pick 3-5 tags
    final count = 3 + _random.nextInt(3);
    final shuffled = List<String>.from(tagPool)..shuffle(_random);
    final selected = shuffled.take(count).toList();

    return jsonEncode({'tags': selected});
  }

  static String _mockClassifyResponse() {
    const categories = [
      'personal',
      'work',
      'study',
      'project',
      'reference',
      'journal',
      'idea',
    ];
    final choice = categories[_random.nextInt(categories.length)];
    return jsonEncode({'category': choice});
  }

  static String _mockConnectionResponse(String prompt) {
    // Try to extract note titles from the prompt
    final lines = prompt.split('\n');
    final titles = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('- ') && !trimmed.startsWith('- Available')) {
        titles.add(trimmed.substring(2));
      }
    }

    if (titles.isEmpty) {
      return jsonEncode({'connections': <String>[]});
    }

    final count = min(3, titles.length);
    final shuffled = List<String>.from(titles)..shuffle(_random);
    return jsonEncode({'connections': shuffled.take(count).toList()});
  }
}
