/// Local notification service.
///
/// Wraps `flutter_local_notifications` so the rest of the app can schedule and
/// cancel reminders without knowing the platform plugin. All notifications are
/// delivered entirely on-device — nothing is sent to a server.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Singleton notification service.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// The notification channel id used for all Healthie reminders.
  static const String _channelId = 'healthie_reminders';

  /// Whether the app may post notifications.
  ///
  /// False on Android 13+ before the user grants the runtime permission, and
  /// false when notifications are disabled at the OS level on any version.
  Future<bool> areNotificationsEnabled() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    return await android.areNotificationsEnabled() ?? false;
  }

  /// Asks for the notification permission. Shows the OS prompt on Android 13+
  /// and opens nothing on older versions, where install-time consent covers
  /// notifications. Returns true when notifications may be posted.
  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    return await android.requestNotificationsPermission() ?? false;
  }

  /// Initializes the plugin and creates the Android notification channel.
  /// Must be called once from `main()` before any notifications are scheduled.
  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const settings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
    );

    // Create the reminder channel (Android 8+).
    await _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _channelId,
          'Healthie Reminders',
          description:
              'Reminders for blood pressure, weight, medication, and other health checks.',
          importance: Importance.high,
          enableVibration: true,
          enableLights: true,
          sound: RawResourceAndroidNotificationSound('notification'),
        ));

    tz.initializeTimeZones();
    _initialized = true;
  }

  /// Called when the user taps a notification.
  ///
  /// Payload format: `reminder:<id>` or `medication:<id>`. Navigation is
  /// handled by the router via a global key; this hook exists so taps can be
  /// observed (e.g. in tests) without coupling the service to navigation.
  void _onDidReceiveNotificationResponse(NotificationResponse details) {
    _lastTappedPayload = details.payload;
  }

  /// The payload of the most recently tapped notification, if any.
  String? _lastTappedPayload;

  /// The payload of the most recently tapped notification, for tests.
  @visibleForTesting
  String? get lastTappedPayload => _lastTappedPayload;

  /// Schedules a daily reminder at [hour]:[minute] local time.
  ///
  /// [id] must be unique per reminder. [title] and [body] are the notification
  /// content. [payload] is passed back when the notification is tapped.
  Future<void> scheduleDailyReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? payload,
  }) async {
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: _nextDailyTime(hour, minute),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Healthie Reminders',
          channelDescription: 'Health reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
  }

  /// Cancels a scheduled reminder by [id].
  Future<void> cancelReminder(int id) async {
    await _plugin.cancel(id: id);
  }

  /// Cancels all scheduled reminders.
  Future<void> cancelAllReminders() async {
    await _plugin.cancelAll();
  }

  /// Cancels all scheduled reminders (alias for compatibility).
  Future<void> cancelAll() async {
    await cancelAllReminders();
  }

  /// Returns the next occurrence of [hour]:[minute] in local time.
  tz.TZDateTime _nextDailyTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
