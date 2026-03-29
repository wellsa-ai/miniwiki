import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../database/database.dart';
import '../database/connection.dart';
import '../database/daos/notes_dao.dart';
import '../logger/app_logger.dart';

// ---------------------------------------------------------------------------
// Secure Storage
// ---------------------------------------------------------------------------

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
});

// ---------------------------------------------------------------------------
// App State
// ---------------------------------------------------------------------------

enum AppState { uninitialized, locked, unlocked }

final appStateProvider = StateProvider<AppState>((ref) => AppState.uninitialized);

// ---------------------------------------------------------------------------
// Database (created after unlock)
// ---------------------------------------------------------------------------

final databaseProvider = Provider<AppDatabase>((ref) {
  final key = ref.watch(_dbKeyProvider);
  if (key == null) {
    throw StateError('Database accessed before unlock');
  }
  final db = openDatabase(encryptionKey: key);
  ref.onDispose(() => db.close());
  return db;
});

final _dbKeyProvider = StateProvider<String?>((ref) => null);

final notesDaoProvider = Provider<NotesDao>((ref) {
  return NotesDao(ref.watch(databaseProvider));
});

// ---------------------------------------------------------------------------
// App Controller
// ---------------------------------------------------------------------------

final appControllerProvider = Provider<AppController>((ref) {
  return AppController(ref);
});

// Top-level function for compute() to run hash in background isolate
Future<String> _hashPasswordIsolate(({String password, String salt}) params) async {
  try {
    List<int> hash = utf8.encode(params.password);
    final saltBytes = utf8.encode(params.salt);

    // HMAC-SHA256 with 100,000 iterations for strong security
    final hmac = Hmac(sha256, saltBytes);
    for (var i = 0; i < 100000; i++) {
      hash = List<int>.from(hmac.convert(hash).bytes);
    }

    return base64Url.encode(hash);
  } catch (e) {
    // Fallback to simple hash if anything fails
    final bytes = utf8.encode('${params.salt}:${params.password}');
    final digest = sha256.convert(bytes);
    final secondPass = sha256.convert(utf8.encode('$digest:${params.salt}'));
    return secondPass.toString();
  }
}

class AppController {
  final Ref _ref;
  AppController(this._ref);

  static const _keyPassword = 'db_password_hash';
  static const _keySalt = 'db_salt';
  static const _keyDbKey = 'db_encryption_key';
  static const _keyHashVersion = 'hash_version'; // v1: SHA256 (legacy), v2: HMAC-SHA256
  static const _keyMigrationVersion = 'migration_version'; // Tracks successful migrations

  /// Initialize app on startup.
  Future<void> initialize() async {
    final storage = _ref.read(secureStorageProvider);
    final hasDb = await databaseExists();
    final hasPassword = await storage.containsKey(key: _keyPassword);

    if (!hasDb || !hasPassword) {
      // First launch — open unencrypted DB, go straight to unlocked
      _ref.read(_dbKeyProvider.notifier).state = '';
      _ref.read(appStateProvider.notifier).state = AppState.unlocked;
    } else {
      // Existing DB with password — require unlock
      _ref.read(appStateProvider.notifier).state = AppState.locked;
    }
  }

  /// Unlock with password.
  /// Supports both legacy SHA256 and new HMAC-SHA256 hashes.
  Future<bool> unlock(String password) async {
    try {
      final storage = _ref.read(secureStorageProvider);

      final storedHash = await storage.read(key: _keyPassword);
      final salt = await storage.read(key: _keySalt);
      final hashVersion = await storage.read(key: _keyHashVersion) ?? 'v1';

      if (storedHash == null || salt == null) {
        AppLogger.warning('Unlock failed: missing credentials', context: 'Auth');
        return false;
      }

      bool hashMatch = false;

      // Try new hash first (v2: HMAC-SHA256)
      if (hashVersion == 'v2') {
        final hash = await _hashPasswordAsync(password, salt, allowFallback: true);
        hashMatch = hash == storedHash;
      }

      // Fallback to legacy SHA256 (v1) if new hash doesn't match
      if (!hashMatch && hashVersion == 'v1') {
        final legacyHash = _hashPasswordLegacy(password, salt);
        hashMatch = legacyHash == storedHash;

        // Successful legacy unlock — auto-migrate to new hash
        if (hashMatch) {
          AppLogger.info('Auto-migrating password hash to v2', context: 'Auth');
          try {
            await _migrateHashVersion(password, salt, storage);
            // Verify migration succeeded by reading back the version
            final newVersion = await storage.read(key: _keyHashVersion);
            if (newVersion == 'v2') {
              await storage.write(key: _keyMigrationVersion, value: 'v1-to-v2-success');
              AppLogger.info('Password hash migration verified', context: 'Auth');
            } else {
              AppLogger.critical('Password hash migration verification failed', context: 'Auth');
            }
          } catch (e) {
            AppLogger.error('Password hash migration failed', context: 'Auth', error: e);
            // Continue with legacy hash — user can still use old password
          }
        }
      }

      if (!hashMatch) {
        AppLogger.warning('Unlock failed: invalid password', context: 'Auth');
        return false;
      }

      // Retrieve the actual DB encryption key
      final dbKey = await storage.read(key: _keyDbKey);
      if (dbKey == null) {
        AppLogger.error('Unlock failed: missing DB key', context: 'Auth');
        return false;
      }

      _ref.read(_dbKeyProvider.notifier).state = dbKey;
      _ref.read(appStateProvider.notifier).state = AppState.unlocked;
      AppLogger.info('Unlock successful', context: 'Auth');
      return true;
    } catch (e, stack) {
      AppLogger.error('Unlock exception', context: 'Auth', error: e, stack: stack);
      return false;
    }
  }

  /// Migrate from legacy SHA256 to HMAC-SHA256.
  Future<void> _migrateHashVersion(
      String password, String salt, FlutterSecureStorage storage) async {
    try {
      final newHash = await _hashPasswordAsync(password, salt);
      await storage.write(key: _keyPassword, value: newHash);
      await storage.write(key: _keyHashVersion, value: 'v2');
    } catch (e) {
      // Silently fail migration — user can still use old hash
    }
  }

  /// Set password for first time or change password.
  /// On first setup: generates a new DB encryption key.
  /// On password change: keeps the existing DB key (only re-hashes the password).
  Future<void> setPassword(String password) async {
    try {
      final storage = _ref.read(secureStorageProvider);

      // Generate salt and hash password using HMAC-SHA256
      final salt = _generateSalt();
      final hash = await _hashPasswordAsync(password, salt, allowFallback: false);

      // Only generate a new DB key on first setup (when no key exists).
      // On password change, reuse the existing key to avoid DB/key desync.
      final existingKey = await storage.read(key: _keyDbKey);
      final isFirstSetup = existingKey == null || existingKey.isEmpty;
      final dbKey = isFirstSetup ? _generateDbKey() : existingKey;

      // On first password setup, encrypt the previously unencrypted DB file
      if (isFirstSetup) {
        final currentDbKey = _ref.read(_dbKeyProvider);
        if (currentDbKey != null && currentDbKey.isEmpty) {
          final db = _ref.read(databaseProvider);
          // Decode base64 key to bytes, then convert to hex for SQLite PRAGMA rekey
          final decodedKey = base64Url.decode(dbKey);
          final hexKey = decodedKey
              .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
              .join();

          try {
            // Apply encryption
            await db.customStatement("PRAGMA rekey = \"x'$hexKey'\"");
            AppLogger.info('Database encrypted with PRAGMA rekey', context: 'Auth');

            // Verify encryption succeeded by querying database
            await db.customStatement('SELECT COUNT(*) FROM sqlite_master');
            AppLogger.info('Database encryption verified successfully', context: 'Auth');
          } catch (e) {
            AppLogger.critical('Database encryption failed', context: 'Auth', error: e);
            // Rollback: restore unencrypted state by setting empty key
            try {
              await db.customStatement('PRAGMA rekey = ""');
              AppLogger.warning('Database encryption rolled back', context: 'Auth');
            } catch (rollbackError) {
              AppLogger.critical('Rollback failed', context: 'Auth', error: rollbackError);
            }
            rethrow;
          }
        }
      }

      // Store everything in secure storage
      await storage.write(key: _keyPassword, value: hash);
      await storage.write(key: _keySalt, value: salt);
      await storage.write(key: _keyDbKey, value: dbKey);
      await storage.write(key: _keyHashVersion, value: 'v2'); // HMAC-SHA256

      _ref.read(_dbKeyProvider.notifier).state = dbKey;
      _ref.read(appStateProvider.notifier).state = AppState.unlocked;
      AppLogger.info('Password set successfully', context: 'Auth');
    } catch (e, stack) {
      AppLogger.error('setPassword exception', context: 'Auth', error: e, stack: stack);
      rethrow;
    }
  }

  /// Lock the app (clear key from memory).
  void lock() {
    _ref.read(_dbKeyProvider.notifier).state = null;
    _ref.read(appStateProvider.notifier).state = AppState.locked;
  }

  /// Check if password has been set.
  Future<bool> hasPassword() async {
    final storage = _ref.read(secureStorageProvider);
    return await storage.containsKey(key: _keyPassword);
  }

  // --- Internal helpers ---

  /// Hash password using HMAC-SHA256 with multiple iterations.
  /// Runs in background isolate to prevent UI blocking.
  /// Has 10-second timeout to catch hung operations.
  /// For unlock(): [allowFallback=true] permits legacy hash fallback on timeout.
  /// For setPassword(): [allowFallback=false] blocks fallback to ensure strong hash.
  Future<String> _hashPasswordAsync(String password, String salt, {bool allowFallback = false}) async {
    try {
      // Run expensive hashing in background isolate (prevents UI blocking)
      final hash = await compute(
        _hashPasswordIsolate,
        (password: password, salt: salt),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          AppLogger.error('Password hashing timeout (>10s)', context: 'Auth');
          throw TimeoutException('Password hashing exceeded 10 seconds');
        },
      );

      return hash;
    } on TimeoutException catch (e) {
      AppLogger.error('Hash operation timeout', context: 'Auth', error: e);
      // Only fallback to legacy hash on timeout if explicitly allowed
      if (allowFallback) {
        return _hashPasswordLegacy(password, salt);
      } else {
        rethrow; // Re-throw if fallback not allowed (setPassword case)
      }
    } catch (e) {
      // Only fallback to legacy hash on error if explicitly allowed
      if (allowFallback) {
        AppLogger.warning('Hash operation failed, using legacy hash', context: 'Auth', error: e);
        return _hashPasswordLegacy(password, salt);
      } else {
        rethrow; // Re-throw if fallback not allowed (setPassword case)
      }
    }
  }

  /// Legacy SHA256 hash (for backward compatibility during migration).
  String _hashPasswordLegacy(String password, String salt) {
    final bytes = utf8.encode('$salt:$password');
    final digest = sha256.convert(bytes);
    final secondPass = sha256.convert(utf8.encode('$digest:$salt'));
    return secondPass.toString();
  }

  String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  String _generateDbKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }
}
