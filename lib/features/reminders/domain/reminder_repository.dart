/// The interface for reading and writing reminders.
library;

import 'reminder.dart';

abstract interface class ReminderRepository {
  /// Every reminder, ordered by time of day.
  Stream<List<Reminder>> watchAll();

  /// Writes a reminder.
  Future<void> upsert(Reminder reminder);

  /// Removes a reminder.
  Future<void> delete(String id);
}
