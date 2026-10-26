/// Scheduled measurement reminders.
///
/// Reminders are local notifications. They depend on the device's own
/// settings and may not always be delivered — the UI says so rather than
/// promising that a reminder will arrive.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'reminder.freezed.dart';

/// The kinds of reminder Healthie can schedule.
enum ReminderKind {
  /// A morning blood-pressure check.
  morningBloodPressure('morning_blood_pressure', 'Morning BP'),

  /// An evening blood-pressure check.
  eveningBloodPressure('evening_blood_pressure', 'Evening BP'),

  /// A weight check.
  weight('weight', 'Weight check'),

  /// A medication dose.
  medication('medication', 'Medication'),

  /// A user-defined check.
  custom('custom', 'Check');

  const ReminderKind(this.wireName, this.label);

  final String wireName;
  final String label;

  static ReminderKind fromWireName(String wireName) =>
      ReminderKind.values.firstWhere(
        (kind) => kind.wireName == wireName,
        orElse: () => ReminderKind.custom,
      );
}

@freezed
abstract class Reminder with _$Reminder {
  const factory Reminder({
    required String id,
    required ReminderKind kind,
    required String metricType,
    required String title,
    required int hour,
    required int minute,
    @Default(true) bool enabled,
  }) = _Reminder;

  const Reminder._();

  /// The moment this reminder fires today.
  DateTime nextOccurrence(DateTime now) {
    final today = DateTime(now.year, now.month, now.day, hour, minute);
    if (today.isAfter(now)) return today;
    return today.add(const Duration(days: 1));
  }

  /// Whether the reminder is due on [day].
  bool isDueOn(DateTime day) => enabled;
}
