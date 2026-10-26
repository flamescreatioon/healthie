/// A scheduled reminder for a measurement.
///
/// Reminders are local notifications. They depend on device settings and may
/// not always be delivered — the UI says so.
library;

import 'package:drift/drift.dart';

@DataClassName('ReminderRow')
class Reminders extends Table {
  TextColumn get id => text()();

  /// The reminder kind's wire name, e.g. `morning_blood_pressure`.
  TextColumn get kind => text()();

  /// The metric's wire name the reminder is about.
  TextColumn get metricType => text()();

  /// The title shown in the notification.
  TextColumn get title => text()();

  /// Local hour of day, 0–23.
  IntColumn get hour => integer()();

  /// Local minute of hour, 0–59.
  IntColumn get minute => integer()();

  /// Whether the reminder is switched on.
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  /// The IANA time zone the schedule was created in.
  TextColumn get timeZone => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
