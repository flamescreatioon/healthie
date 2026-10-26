/// Access to the offline write-ahead queue.
///
/// The outbox is transient machinery — the only table in the app that may be
/// purged on a schedule. Everything else is user history and is never hard
/// deleted.
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/app_database.dart';

class SyncOutboxDao {
  const SyncOutboxDao(this._db);

  final AppDatabase _db;

  /// Enqueues an operation for [entityId].
  Future<void> enqueue({
    required String operation,
    required String entityType,
    required String entityId,
    required Map<String, dynamic> payload,
  }) async {
    await _db.into(_db.syncOutbox).insert(
          SyncOutboxCompanion.insert(
            id: entityId,
            operation: operation,
            entityType: entityType,
            entityId: entityId,
            payload: jsonEncode(payload),
            queuedAt: DateTime.now().toUtc(),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  /// The oldest pending operations, oldest first.
  Future<List<SyncOutboxRow>> pending({int limit = 50}) {
    final query = _db.select(_db.syncOutbox)
      ..where((row) => row.isProcessing.equals(false))
      ..orderBy([(row) => OrderingTerm.asc(row.queuedAt)])
      ..limit(limit);
    return query.get();
  }

  /// How many operations are waiting to be sent.
  Future<int> pendingCount() async {
    final count = _db.syncOutbox.id.count();
    final query = _db.selectOnly(_db.syncOutbox)
      ..addColumns([count])
      ..where(_db.syncOutbox.isProcessing.equals(false));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  /// Claims an operation so a second sync run cannot pick it up.
  ///
  /// The claim is a conditional update, never a read-then-write, so two
  /// concurrent runs cannot both succeed.
  Future<bool> claim(String id) async {
    final changed = await (_db.update(_db.syncOutbox)
          ..where((row) => row.id.equals(id) & row.isProcessing.equals(false)))
        .write(const SyncOutboxCompanion(isProcessing: Value(true)));
    return changed == 1;
  }

  /// Removes a successfully applied operation.
  Future<void> complete(String id) async {
    await (_db.delete(_db.syncOutbox)..where((row) => row.id.equals(id)))
        .go();
  }

  /// Records a failed attempt and releases the claim so it can be retried.
  Future<void> fail(String id, String error) async {
    await _db.customStatement(
      'UPDATE sync_outbox SET last_error = ?, last_attempt_at = ?, '
      'attempts = attempts + 1, is_processing = 0 WHERE id = ?',
      [
        error,
        DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
        id,
      ],
    );
  }
}
