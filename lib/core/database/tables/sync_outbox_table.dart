/// The offline write-ahead queue.
///
/// Every local write enqueues an operation here **in the same transaction** as
/// the write itself. That atomicity is what makes sync crash-safe: the
/// operation and the data are committed together, so a crash can never leave
/// a saved measurement without a pending upload.
library;

import 'package:drift/drift.dart';

@DataClassName('SyncOutboxRow')
class SyncOutbox extends Table {
  TextColumn get id => text()();

  /// `upsert` or `delete`.
  TextColumn get operation => text()();

  /// The entity the operation applies to, e.g. `measurements`.
  TextColumn get entityType => text()();

  /// The id of the affected entity.
  TextColumn get entityId => text()();

  /// The serialised entity, as JSON.
  TextColumn get payload => text()();

  /// When the operation was queued, in UTC.
  DateTimeColumn get queuedAt => dateTime()();

  /// How many times the operation has been attempted.
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  /// The last error message, for diagnostics.
  TextColumn get lastError => text().nullable()();

  /// When the last attempt happened, in UTC.
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();

  /// The claim flag that stops two concurrent sync runs from processing the
  /// same row. Claimed with a conditional update, never a read-then-write.
  BoolColumn get isProcessing => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
