/// Encrypted database opening: key handling, PRAGMA wiring, migration.
///
/// All health data lives in one Drift file, so whole-file SQLCipher
/// encryption covers measurements, medications, reminders, and the sync
/// outbox with a single mechanism. Queries, indexes, and DAOs are unchanged:
/// SQLite decrypts pages transparently once the key is set.
///
/// Opening flow:
/// 1. Read (or create) the 256-bit key from the platform keystore.
/// 2. Migrate a legacy plaintext database, if one exists.
/// 3. Open with `PRAGMA key`, which fails closed on a wrong key.
///
/// Design constraints from `flutter-architecture`:
/// - The provider layer stays synchronous for existing callers: the database
///   is opened eagerly in `main()` (after `WidgetsFlutterBinding` init, which
///   both `path_provider` and `flutter_secure_storage` need) and handed to
///   Riverpod via override.
/// - The key bytes only ever live in this file's call stack, passed straight
///   into the `setup` callback. They are never logged, never put in a URL,
///   never sent anywhere.
library;

import 'dart:io';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/common.dart';
import 'package:sqlite3/sqlite3.dart';

import 'app_database.dart';
import 'database_key.dart';

/// Opens the encrypted app database, migrating from plaintext on first run.
///
/// Throws [StorageFailure] (via the key provider) when the platform keystore
/// is unavailable. A wrong key fails at first query time with a SQLite
/// `SQLITE_NOTADB` error — fail-closed, never fail-open to plaintext.
Future<AppDatabase> openEncryptedDatabase({
  DatabaseKeyProvider? keyProvider,
}) async {
  final keys = keyProvider ?? SecureStorageDatabaseKeyProvider();
  final key = await keys.getOrCreateKey();

  await _migratePlaintextIfNeeded(key);

  return AppDatabase.withExecutor(
    driftDatabase(
      name: 'healthie',
      native: DriftNativeOptions(
        // ignore: avoid_slow_async_io — one file check at startup, not a hot path.
        setup: (db) => _applyKey(db, key),
      ),
    ),
  );
}

/// Sets the SQLCipher key on a freshly opened raw connection.
///
/// The key is bound as a blob parameter rather than interpolated into the
/// SQL string, so it never appears in statement logs or error messages.
void _applyKey(CommonDatabase db, List<int> key) {
  db.execute('PRAGMA key = ?', [key]);
}

/// Copies a legacy plaintext `healthie.sqlite` into the encrypted database.
///
/// Runs before the encrypted open, so the main path only ever sees
/// ciphertext. The in-place `PRAGMA rekey` rewrites every page with the new
/// key and preserves the path drift expects, so there is no file-swap step.
/// If the process dies mid-rekey the file keeps its plaintext readability
/// and the migration simply retries on next launch — never a half-encrypted
/// file presented as done.
///
/// No-op when there is no database file yet, or when the file already opens
/// with [key] (fresh installs and already-migrated installs).
Future<void> _migratePlaintextIfNeeded(List<int> key) async {
  final file = await _databaseFile();
  if (!file.existsSync()) return;
  if (await _opensWithKey(file, key)) return;

  final plain = sqlite3.open(file.path);
  try {
    // Guard: only rekey a readable plaintext database. Anything else
    // (corrupt, wrong key, foreign format) surfaces as an exception instead
    // of being silently overwritten.
    plain.select('SELECT count(*) FROM sqlite_master');
    plain.execute('PRAGMA rekey = ?', [key]);
  } finally {
    plain.close();
  }
}

/// True when [file] opens and answers a probe query with [key].
///
/// Returns false for both plaintext files and wrong-key files; the caller
/// only needs "can drift open this?" — anything else migrates.
Future<bool> _opensWithKey(File file, List<int> key) async {
  final probe = sqlite3.open(file.path);
  try {
    probe.execute('PRAGMA key = ?', [key]);
    probe.select('SELECT count(*) FROM sqlite_master');
    return true;
  } on SqliteException catch (error) {
    // SQLITE_NOTADB (26): not a database, or not encrypted with this key.
    if (error.extendedResultCode == 26) return false;
    rethrow;
  } finally {
    probe.close();
  }
}

/// The file drift opens for `name: 'healthie'`: `$docs/healthie.sqlite`.
///
/// Mirrors `driftDatabase`'s default path construction so the migration looks
/// at the same file the app will open.
Future<File> _databaseFile() async {
  final directory = await getApplicationDocumentsDirectory();
  return File(p.join(directory.path, 'healthie.sqlite'));
}
