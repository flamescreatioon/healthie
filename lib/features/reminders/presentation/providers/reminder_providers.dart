/// Riverpod providers for the reminders feature.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../metrics/domain/metric_type.dart';
import '../../data/reminder_notification_service.dart';
import '../../domain/reminder.dart';
import '../../domain/reminder_repository.dart';

/// Every reminder, updated whenever the table changes.
final remindersProvider = StreamProvider<List<Reminder>>(
  (ref) => ref.watch(reminderDaoProvider).watchAll(),
);

/// Writes to the reminder table.
final reminderControllerProvider = Provider<ReminderController>(
  (ref) => ReminderController(
    ref.watch(reminderDaoProvider),
    ref.watch(reminderNotificationSchedulerProvider),
  ),
);

/// Whether the OS currently allows the app to post notifications.
///
/// UI watches this to explain and prompt at the moment the user wants a
/// reminder — never at app startup.
final notificationPermissionProvider =
    AsyncNotifierProvider<NotificationPermissionController, bool>(
  NotificationPermissionController.new,
);

class NotificationPermissionController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    return ref
        .watch(reminderNotificationSchedulerProvider)
        .notificationsAllowed;
  }

  /// Asks for the notification permission, then refreshes the state so the
  /// banner disappears without a restart when the user grants it.
  Future<void> request() async {
    state = const AsyncValue.loading();
    final granted = await ref
        .read(reminderNotificationSchedulerProvider)
        .requestPermission();
    state = AsyncValue.data(granted);
  }
}

class ReminderController {
  const ReminderController(this._repository, this._scheduler);

  final ReminderRepository _repository;
  final ReminderNotificationScheduler _scheduler;

  /// Writes a reminder, then applies the schedule change.
  Future<void> save(Reminder reminder) async {
    await _repository.upsert(reminder);
    await _scheduler.scheduleOne(reminder);
  }

  /// Switches a reminder on or off, then applies the schedule change.
  Future<void> setEnabled(Reminder reminder, {required bool enabled}) async {
    final updated = reminder.copyWith(enabled: enabled);
    await _repository.upsert(updated);
    await _scheduler.scheduleOne(updated);
  }

  /// Removes a reminder and cancels its notification.
  Future<void> delete(String id) async {
    await _repository.delete(id);
    await _scheduler.cancelAll();
  }

  /// Creates the default pair of blood-pressure checks, if they are missing.
  Future<void> seedDefaults() async {
    await _repository.upsert(
      Reminder(
        id: newId(),
        kind: ReminderKind.morningBloodPressure,
        metricType: MetricType.bloodPressure.wireName,
        title: 'Morning blood pressure',
        hour: 8,
        minute: 15,
      ),
    );
    await _repository.upsert(
      Reminder(
        id: newId(),
        kind: ReminderKind.eveningBloodPressure,
        metricType: MetricType.bloodPressure.wireName,
        title: 'Evening blood pressure',
        hour: 20,
        minute: 0,
      ),
    );
  }
}
