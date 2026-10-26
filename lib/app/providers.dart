/// The composition root.
///
/// This is the one place where the concrete implementations are wired to the
/// abstractions the rest of the app depends on. Everything else talks to
/// domain interfaces; only this file knows that the repository is backed by
/// Drift, or that the database lives in a Drift file.
///
/// Keeping the wiring here is what lets the presentation layer avoid
/// importing the data layer, and what lets a test replace any of these
/// providers with a fake.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/app_database.dart';
import '../core/notifications/notification_service.dart';
import '../core/sync/auth_store.dart';
import '../core/sync/backend_client.dart';
import '../core/sync/measurement_sync_adapter.dart';
import '../core/sync/sync_cursor_dao.dart';
import '../core/sync/sync_outbox_dao.dart';
import '../core/sync/sync_service.dart';
import '../core/utils/clock.dart';
import '../features/medications/data/medication_dao.dart';
import '../features/metrics/data/measurement_dao.dart';
import '../features/metrics/data/measurement_repository_impl.dart';
import '../features/metrics/domain/measurement_repository.dart';
import '../features/profile/data/profile_repository_impl.dart';
import '../features/profile/domain/profile_repository.dart';
import '../features/reminders/data/reminder_dao.dart';
import '../features/reminders/data/reminder_notification_service.dart';

/// The on-device database.
final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

/// The source of "now". Tests override it with a fixed clock.
final clockProvider = Provider<Clock>((ref) => const SystemClock());

/// The offline write-ahead queue.
final syncOutboxDaoProvider = Provider<SyncOutboxDao>(
  (ref) => SyncOutboxDao(ref.watch(databaseProvider)),
);

/// Drift access to the measurements table.
final measurementDaoProvider = Provider<MeasurementDao>(
  (ref) => MeasurementDao(ref.watch(databaseProvider)),
);

/// The bearer token store. Overridden in production with a secure-storage
/// implementation; tests use the in-memory default.
final authTokenStoreProvider = Provider<AuthTokenStore>(
  (ref) => InMemoryAuthTokenStore(),
);

/// The Laravel backend base URL, e.g. `https://api.healthie.example`.
/// Supplied via `--dart-define=HEALTHIE_API_URL=...`.
final backendBaseUrlProvider = Provider<String>((ref) {
  const url = String.fromEnvironment('HEALTHIE_API_URL');
  if (url.isEmpty) {
    throw StateError(
      'HEALTHIE_API_URL is not set. Pass '
      '--dart-define=HEALTHIE_API_URL=https://<host> when running.',
    );
  }
  return url;
});

/// The HTTP client speaking `/api/v1` with the Sanctum bearer token.
final backendClientProvider = Provider<BackendClient>((ref) {
  final client = BackendClient(
    baseUrl: ref.watch(backendBaseUrlProvider),
    tokenProvider: () => ref.watch(authTokenStoreProvider).readToken(),
  );
  ref.onDispose(client.close);
  return client;
});

/// Applies pulled rows to the local database.
final measurementSyncAdapterProvider = Provider<MeasurementSyncAdapter>(
  (ref) => MeasurementSyncAdapter(ref.watch(measurementDaoProvider)),
);

/// The pull cursor, stored in the local database with the pulled rows.
final syncCursorDaoProvider = Provider<SyncCursorDao>(
  (ref) => SyncCursorDao(ref.watch(databaseProvider)),
);

/// Drains the outbox to the backend and applies the changelog.
final syncServiceProvider = Provider<SyncService>(
  (ref) => SyncService(
    database: ref.watch(databaseProvider),
    outbox: ref.watch(syncOutboxDaoProvider),
    cursorDao: ref.watch(syncCursorDaoProvider),
    backend: ref.watch(backendClientProvider),
    applyRemoteChange:
        ref.watch(measurementSyncAdapterProvider).apply,
  ),
);

/// The measurement repository the UI talks to.
final measurementRepositoryProvider = Provider<MeasurementRepository>(
  (ref) => MeasurementRepositoryImpl(
    ref.watch(databaseProvider),
    ref.watch(measurementDaoProvider),
    ref.watch(syncOutboxDaoProvider),
  ),
);

/// The profile repository.
final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepositoryImpl(ref.watch(databaseProvider)),
);

/// Drift access to the reminders table.
final reminderDaoProvider = Provider<ReminderDao>(
  (ref) => ReminderDao(ref.watch(databaseProvider)),
);

/// Drift access to medications and medication logs.
final medicationDaoProvider = Provider<MedicationDao>(
  (ref) => MedicationDao(ref.watch(databaseProvider)),
);

/// Schedules local notifications for reminders.
final reminderNotificationSchedulerProvider =
    Provider<ReminderNotificationScheduler>((ref) {
  return ReminderNotificationScheduler(
    ref.watch(reminderDaoProvider),
    NotificationService.instance,
  );
});
