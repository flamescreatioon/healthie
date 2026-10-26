/// Connects reminders to local notifications.
///
/// Reads enabled reminders from Drift and schedules them via the
/// [NotificationService]. Called on app start and whenever a reminder is
/// created, toggled, or deleted.
library;

import '../../../core/notifications/notification_service.dart';
import '../data/reminder_dao.dart';
import '../domain/reminder.dart';

/// Schedules local notifications for all enabled reminders.
///
/// Should be called once on app startup, and again whenever a reminder is
/// created, toggled, or deleted.
class ReminderNotificationScheduler {
  const ReminderNotificationScheduler(this._dao, this._notificationService);

  final ReminderDao _dao;
  final NotificationService _notificationService;

  /// Whether the OS currently allows the app to post notifications.
  Future<bool> get notificationsAllowed =>
      _notificationService.areNotificationsEnabled();

  /// Asks for the notification permission. Call from UI, not from startup:
  /// the prompt needs the user's attention and an explanation first.
  Future<bool> requestPermission() =>
      _notificationService.requestPermission();

  /// Schedules all currently enabled reminders. Returns false — and schedules
  /// nothing — when the OS permission is missing, so callers can prompt.
  Future<bool> scheduleAll() async {
    if (!await _notificationService.areNotificationsEnabled()) return false;
    final reminders = await _dao.getAllReminders();
    for (final reminder in reminders) {
      if (reminder.enabled) {
        await _scheduleOne(reminder);
      }
    }
    return true;
  }

  /// Schedules (or cancels) a single reminder. Returns false — and schedules
  /// nothing — when the OS permission is missing.
  Future<bool> scheduleOne(Reminder reminder) async {
    if (!reminder.enabled) {
      await _notificationService.cancelReminder(reminder.id.hashCode);
      return true;
    }
    if (!await _notificationService.areNotificationsEnabled()) return false;
    await _scheduleOne(reminder);
    return true;
  }

  /// Cancels all scheduled reminder notifications.
  Future<void> cancelAll() async {
    await _notificationService.cancelAll();
  }

  Future<void> _scheduleOne(Reminder reminder) async {
    await _notificationService.scheduleDailyReminder(
      id: reminder.id.hashCode,
      title: reminder.title,
      body: 'Time for ${reminder.title.toLowerCase()}',
      hour: reminder.hour,
      minute: reminder.minute,
      payload: 'reminder:${reminder.id}',
    );
  }
}

