/// Stores the pull cursor in the local database, not in shared preferences.
///
/// The cursor and the pulled rows are applied in the same transaction, so a
/// crash can never leave applied rows without their watermark — otherwise the
/// next pull would re-fetch and re-apply the same window forever.
library;

import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// A single-row table holding the `sync/changes` watermark.
class SyncState extends Table {
  /// Always `1`: this table holds exactly one row.
  IntColumn get id => integer()();

  /// The last `server_timestamp` applied, in UTC.
  DateTimeColumn get cursor => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SyncCursorDao {
  const SyncCursorDao(this._db);

  final AppDatabase _db;

  /// The last applied server watermark, or null before the first pull.
  Future<DateTime?> getCursor() async {
    final row = await (_db.select(
      _db.syncState,
    )..where((state) => state.id.equals(1))).getSingleOrNull();
    return row?.cursor?.toUtc();
  }

  /// Advances the cursor. Call inside the same transaction as the row writes.
  Future<void> setCursor(DateTime cursor) async {
    await _db.into(_db.syncState).insertOnConflictUpdate(
          SyncStateCompanion.insert(
            id: const Value(1),
            cursor: Value(cursor.toUtc()),
          ),
        );
  }
}
