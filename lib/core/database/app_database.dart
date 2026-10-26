/// The local Drift database — the source of truth for everything the UI shows.
///
/// The network is never on the critical path of a user-visible write. A
/// measurement saved here is already visible in the UI, whether or not a
/// backend exists.
library;

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../sync/sync_cursor_dao.dart';
import 'tables/goals_table.dart';
import 'tables/measurements_table.dart';
import 'tables/medication_logs_table.dart';
import 'tables/medications_table.dart';
import 'tables/profiles_table.dart';
import 'tables/reminders_table.dart';
import 'tables/sync_outbox_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Measurements,
    Profiles,
    Goals,
    Reminders,
    SyncOutbox,
    SyncState,
    Medications,
    MedicationLogs,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase._(super.executor);

  /// Opens the encrypted database. Prefer [openEncryptedDatabase], which
  /// handles key retrieval and plaintext migration; this factory exists for
  /// call sites that already hold a configured executor.
  factory AppDatabase.withExecutor(QueryExecutor executor) =>
      AppDatabase._(executor);

  /// Opens the on-device database in the application's support directory.
  factory AppDatabase() => AppDatabase._(_openConnection());

  /// An in-memory database, for tests.
  factory AppDatabase.forTesting(QueryExecutor executor) =>
      AppDatabase._(executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createIndexes();
        },
        onUpgrade: (m, from, to) async {
          // Migrations are permanent. Every schema change from version 2 on
          // gets its own guarded block here, plus a migration test.
          await _createIndexes();
        },
      );

  static QueryExecutor _openConnection() =>
      driftDatabase(name: 'healthie', native: const DriftNativeOptions());

  /// The indexes the dashboard's hot queries rely on.
  ///
  /// Created in a migration rather than in `onCreate` alone, so that existing
  /// installs receive them too.
  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_measurements_local_day '
      'ON measurements(local_day)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_measurements_type_day '
      'ON measurements(metric_type, local_day)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_measurements_recorded_at '
      'ON measurements(recorded_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sync_outbox_pending '
      'ON sync_outbox(is_processing, queued_at)',
    );
  }
}
