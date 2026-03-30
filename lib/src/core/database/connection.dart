import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'database.dart';

/// Creates a database connection with optional encryption.
///
/// When [encryptionKey] is non-empty, applies SQLite3MultipleCiphers
/// page-level encryption (ChaCha20-Poly1305 default cipher).
///
/// When [encryptionKey] is empty, opens an unencrypted DB (first-launch /
/// no-password mode).
AppDatabase openDatabase({required String encryptionKey}) {
  return AppDatabase(_openConnection(encryptionKey));
}

LazyDatabase _openConnection(String key) {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final dbDir = Directory(p.join(dir.path, 'miniwiki'));
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }
    final file = File(p.join(dbDir.path, 'wiki.db'));

    return NativeDatabase.createInBackground(
      file,
      setup: (db) {
        // Apply encryption only when key is provided
        if (key.isNotEmpty) {
          // SQLite3MultipleCiphers: PRAGMA key activates encryption
          // Default cipher: chacha20 (ChaCha20-Poly1305)
          // Default KDF: sqleet (legacy) — for Argon2id, set cipher_kdf
          // Decode base64 key to actual bytes, then convert to hex
          // Must match the encoding in app_providers.dart setPassword()
          final decodedKey = base64Url.decode(key);
          final hexKey = decodedKey
              .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
              .join();
          db.execute("PRAGMA key = \"x'$hexKey'\"");

          // Verify encryption is working by reading a page
          // If key is wrong this will throw
          try {
            db.execute('SELECT count(*) FROM sqlite_master');
          } catch (e) {
            throw StateError(
              'Failed to open encrypted database. Wrong password? ($e)',
            );
          }
        }

        // Performance and safety pragmas
        db.execute('PRAGMA journal_mode = WAL');
        db.execute('PRAGMA foreign_keys = ON');
        db.execute('PRAGMA busy_timeout = 5000');
        db.execute('PRAGMA cache_size = -8000'); // 8MB cache
      },
    );
  });
}

/// Check if a database file already exists (to distinguish first-launch).
Future<bool> databaseExists() async {
  final dir = await getApplicationSupportDirectory();
  final file = File(p.join(dir.path, 'miniwiki', 'wiki.db'));
  return file.exists();
}

/// Delete all database files (for reset/wipe).
Future<void> deleteDatabaseFiles() async {
  final dir = await getApplicationSupportDirectory();
  final dbDir = Directory(p.join(dir.path, 'miniwiki'));
  if (await dbDir.exists()) {
    await dbDir.delete(recursive: true);
  }
}
