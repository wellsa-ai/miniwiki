/// High-level AI service that wraps the LLM engine.
///
/// [AiService] is the single entry-point for all AI features:
/// auto-tagging, category classification, and connection suggestions.
/// It manages model lifecycle and gracefully degrades when the native
/// library is unavailable (mock mode).
library;

import 'dart:convert';

import 'ai_prompts.dart';
import 'llama_ffi.dart';

// ---------------------------------------------------------------------------
// Result types
// ---------------------------------------------------------------------------

/// Result of an AI tag-suggestion request.
class TagSuggestionResult {
  final List<String> tags;
  final bool isMock;

  const TagSuggestionResult({required this.tags, required this.isMock});
}

/// Result of an AI category-classification request.
class ClassificationResult {
  final String category;
  final bool isMock;

  const ClassificationResult({required this.category, required this.isMock});
}

/// Result of an AI connection-suggestion request.
class ConnectionSuggestionResult {
  final List<String> connections;
  final bool isMock;

  const ConnectionSuggestionResult({
    required this.connections,
    required this.isMock,
  });
}

// ---------------------------------------------------------------------------
// AiService
// ---------------------------------------------------------------------------

class AiService {
  final LlamaFfi _llama = LlamaFfi();

  /// Whether the model is loaded and ready.
  bool get isReady => _llama.isInitialized;

  /// Whether we are running with mock responses.
  bool get isMock => _llama.isMock;

  /// Load the model from [modelPath].
  ///
  /// If the native library is missing, silently falls back to mock mode.
  Future<void> loadModel(String modelPath) async {
    if (_llama.isInitialized) return;
    await _llama.init(modelPath);
  }

  /// Ensure the model is loaded, using a default path if needed.
  ///
  /// This is a convenience method for providers that need the service
  /// to be ready without knowing the exact model path. In production
  /// the path comes from settings; in dev/test the mock kicks in.
  Future<void> ensureReady() async {
    if (_llama.isInitialized) return;
    // Default model path — will fall back to mock if file does not exist
    await _llama.init('assets/models/qwen2.5-1.5b-instruct-q4_k_m.gguf');
  }

  /// Suggest tags for a note.
  ///
  /// [title] and [content] describe the note. [existingTags] helps the
  /// model prefer reusing tags that already exist in the wiki.
  Future<TagSuggestionResult> suggestTags({
    required String title,
    required String content,
    List<String> existingTags = const [],
  }) async {
    await ensureReady();

    final prompt = AiPrompts.tagSuggestion(
      title: title,
      content: content,
      existingTags: existingTags,
    );

    final raw = await _llama.generate(prompt, maxTokens: 128);
    final tags = _parseTagsResponse(raw);

    return TagSuggestionResult(tags: tags, isMock: _llama.isMock);
  }

  /// Default categories used when none are specified.
  static const defaultCategories = [
    'personal',
    'work',
    'study',
    'project',
    'reference',
    'journal',
    'idea',
  ];

  /// Classify a note into a category.
  Future<ClassificationResult> classifyNote({
    required String title,
    required String content,
    List<String> categories = const [],
  }) async {
    await ensureReady();

    final prompt = AiPrompts.classifyNote(
      title: title,
      content: content,
      categories: categories.isNotEmpty ? categories : defaultCategories,
    );

    final raw = await _llama.generate(prompt, maxTokens: 64);
    final category = _parseClassifyResponse(raw);

    return ClassificationResult(category: category, isMock: _llama.isMock);
  }

  /// Suggest connections to other notes.
  Future<ConnectionSuggestionResult> suggestConnections({
    required String title,
    required String content,
    required List<String> otherNoteTitles,
  }) async {
    await ensureReady();

    final prompt = AiPrompts.suggestConnections(
      title: title,
      content: content,
      otherNoteTitles: otherNoteTitles,
    );

    final raw = await _llama.generate(prompt, maxTokens: 128);
    final connections = _parseConnectionsResponse(raw);

    return ConnectionSuggestionResult(
      connections: connections,
      isMock: _llama.isMock,
    );
  }

  /// Release all model resources.
  void dispose() {
    _llama.dispose();
  }

  // -------------------------------------------------------------------------
  // JSON response parsers — tolerant of malformed model output
  // -------------------------------------------------------------------------

  List<String> _parseTagsResponse(String raw) {
    try {
      final json = jsonDecode(_extractJson(raw)) as Map<String, dynamic>;
      final tags = json['tags'] as List<dynamic>?;
      if (tags != null) {
        return tags.map((e) => e.toString().trim()).where((t) => t.isNotEmpty).toList();
      }
    } catch (_) {
      // Model produced invalid JSON — try to salvage
    }
    return _fallbackExtractTags(raw);
  }

  String _parseClassifyResponse(String raw) {
    try {
      final json = jsonDecode(_extractJson(raw)) as Map<String, dynamic>;
      final category = json['category'] as String?;
      if (category != null && category.isNotEmpty) return category;
    } catch (_) {
      // Model produced invalid JSON
    }
    return 'reference'; // safe default
  }

  List<String> _parseConnectionsResponse(String raw) {
    try {
      final json = jsonDecode(_extractJson(raw)) as Map<String, dynamic>;
      final conns = json['connections'] as List<dynamic>?;
      if (conns != null) {
        return conns.map((e) => e.toString().trim()).where((t) => t.isNotEmpty).toList();
      }
    } catch (_) {
      // Model produced invalid JSON
    }
    return [];
  }

  /// Try to extract the first JSON object from potentially noisy model output.
  String _extractJson(String raw) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return raw.substring(start, end + 1);
    }
    return raw;
  }

  /// Last-resort tag extraction: look for quoted strings in the output.
  List<String> _fallbackExtractTags(String raw) {
    final matches = RegExp(r'"([^"]+)"').allMatches(raw);
    final tags = <String>[];
    for (final m in matches) {
      final tag = m.group(1)?.trim();
      if (tag != null &&
          tag.isNotEmpty &&
          tag != 'tags' &&
          !tag.contains(':')) {
        tags.add(tag);
      }
    }
    return tags.take(5).toList();
  }
}
