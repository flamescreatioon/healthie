/// Drift access for the reminders table.
library;

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/reminder.dart';
import '../domain/reminder_repository.dart';

class ReminderDao implements ReminderRepository {
  const ReminderDao(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Reminder>> watchAll() {
    final query = _db.select(_db.reminders)
      ..orderBy([
        (row) => OrderingTerm.asc(row.hour),
        (row) => OrderingTerm.asc(row.minute),
      ]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  Future<List<Reminder>> getAllReminders() async {
    final rows = await _db.select(_db.reminders).get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<void> upsert(Reminder reminder) async {
    final now = DateTime.now().toUtc();
    await _db.into(_db.reminders).insertOnConflictUpdate(
          RemindersCompanion.insert(
            id: reminder.id,
            kind: reminder.kind.wireName,
            metricType: reminder.metricType,
            title: reminder.title,
            hour: reminder.hour,
            minute: reminder.minute,
            enabled: Value(reminder.enabled),
            timeZone: Value(DateTime.now().timeZoneName),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  @override
  Future<void> delete(String id) async {
    await (_db.delete(_db.reminders)..where((row) => row.id.equals(id))).go();
  }

  static Reminder _toDomain(ReminderRow row) => Reminder(
        id: row.id,
        kind: ReminderKind.fromWireName(row.kind),
        metricType: row.metricType,
        title: row.title,
        hour: row.hour,
        minute: row.minute,
        enabled: row.enabled,
      );
}
