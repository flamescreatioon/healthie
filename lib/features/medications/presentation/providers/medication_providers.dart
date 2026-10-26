/// Riverpod providers for medications.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../reminders/data/reminder_notification_service.dart';
import '../../../reminders/domain/reminder.dart';
import '../../../reminders/domain/reminder_repository.dart';
import '../../data/medication_dao.dart';
import '../../data/medication_repository_impl.dart';
import '../../domain/medication.dart';
import '../../domain/medication_repository.dart';

/// The medication repository.
final medicationRepositoryProvider = Provider<MedicationRepository>(
  (ref) => MedicationRepositoryImpl(ref.watch(medicationDaoProvider)),
);

/// Drift access to medications and logs.
final medicationDaoProvider = Provider<MedicationDao>((ref) =>
    MedicationDao(ref.watch(databaseProvider)));

/// All medications, reactive.
final medicationsProvider = StreamProvider<List<Medication>>(
  (ref) => ref.watch(medicationRepositoryProvider).watchMedications(),
);

/// All medication logs, reactive.
final medicationLogsProvider = StreamProvider<List<MedicationLog>>(
  (ref) => ref.watch(medicationRepositoryProvider).watchMedicationLogs(),
);

/// Writes to medications and logs, and keeps dose reminders in step.
final medicationControllerProvider = Provider<MedicationController>(
  (ref) => MedicationController(
    ref.watch(medicationRepositoryProvider),
    ref.watch(reminderDaoProvider),
    ref.watch(reminderNotificationSchedulerProvider),
  ),
);

class MedicationController {
  const MedicationController(
    this._repository,
    this._reminders,
    this._scheduler,
  );

  final MedicationRepository _repository;
  final ReminderRepository _reminders;
  final ReminderNotificationScheduler _scheduler;

  Future<void> saveMedication(
    Medication medication, {
    bool remindMe = false,
  }) async {
    await _repository.saveMedication(medication);
    if (remindMe) {
      await syncDoseReminders(medication);
    }
  }

  Future<void> deleteMedication(String id) async {
    await _repository.deleteMedication(id);
    await removeDoseReminders(id);
  }

  Future<void> logMedication(MedicationLog log) =>
      _repository.logMedication(log);

  Future<List<MedicationLog>> getLogsForMedication(String medicationId) =>
      _repository.getLogsForMedication(medicationId);

  /// The dose reminders currently linked to [medicationId].
  Future<List<Reminder>> doseRemindersFor(String medicationId) async {
    final all = await _reminders.watchAll().first;
    return all.where((reminder) => _doseOwner(reminder) == medicationId).toList();
  }

  /// Rebuilds the dose reminders for [medication] from its schedule.
  ///
  /// Existing linked reminders are replaced so edits (renames, time changes)
  /// never leave stale notifications behind. Each schedule slot becomes one
  /// `medication`-kind reminder titled with the medication name.
  Future<void> syncDoseReminders(Medication medication) async {
    final previous = await doseRemindersFor(medication.id);
    for (final reminder in previous) {
      await _reminders.delete(reminder.id);
      await _scheduler.cancelAll();
    }
    for (final slot in _parseSchedule(medication.schedule)) {
      final reminder = Reminder(
        id: newId(),
        kind: ReminderKind.medication,
        metricType: 'medication:${medication.id}',
        title: 'Take ${medication.name}',
        hour: slot.hour,
        minute: slot.minute,
      );
      await _reminders.upsert(reminder);
      await _scheduler.scheduleOne(reminder);
    }
  }

  /// Removes every dose reminder linked to [medicationId].
  Future<void> removeDoseReminders(String medicationId) async {
    final linked = await doseRemindersFor(medicationId);
    for (final reminder in linked) {
      await _reminders.delete(reminder.id);
    }
    await _scheduler.cancelAll();
  }

  /// Links a reminder back to its medication via the `metricType` field:
  /// `medication:<id>`. Returns null for non-dose reminders.
  static String? _doseOwner(Reminder reminder) {
    const prefix = 'medication:';
    if (reminder.kind != ReminderKind.medication) return null;
    if (!reminder.metricType.startsWith(prefix)) return null;
    return reminder.metricType.substring(prefix.length);
  }

  /// Parses `HH:MM` slots from a schedule string like `"08:00, 20:00"`.
  /// Malformed slots are skipped, never fatal.
  static List<({int hour, int minute})> _parseSchedule(String schedule) {
    final slots = <({int hour, int minute})>[];
    for (final part in schedule.split(',')) {
      final piece = part.trim().split(':');
      if (piece.length != 2) continue;
      final hour = int.tryParse(piece[0].trim());
      final minute = int.tryParse(piece[1].trim());
      if (hour == null || minute == null) continue;
      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) continue;
      slots.add((hour: hour, minute: minute));
    }
    return slots;
  }
}
