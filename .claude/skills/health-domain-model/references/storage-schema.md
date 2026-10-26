# Healthie Storage Schema (Drift)

Drift 2.35.2 / `drift_dev` 2.35.1. Table definitions live in
`core/database/tables/`. The database class is `core/database/app_database.dart`.

## Core Table: Measurements

Most metrics are plain scalar values over time. One table with a metric-type
discriminator beats one table per metric: it keeps queries uniform, makes the
dashboard's "everything on this day" query trivial, and lets sync treat every
metric the same way.

```dart
class Measurements extends Table {
  TextColumn get id => text()();
  TextColumn get metricType => text()();        // the wireName from the catalog
  RealColumn get value => real()();
  TextColumn get unit => text()();              // canonical unit
  DateTimeColumn get recordedAt => dateTime()();// UTC
  DateTimeColumn get localDay => dateTime()();  // local midnight, for rollups
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get source => text()();            // manual | healthConnect | imported | derived
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

Add indexes for the two access patterns that matter:

```dart
@override
List<Set<Column>> get customConstraints => [];
```

Create the indexes in a migration:

```sql
CREATE INDEX IF NOT EXISTS idx_measurements_local_day
  ON measurements(local_day);
CREATE INDEX IF NOT EXISTS idx_measurements_type_day
  ON measurements(metric_type, local_day);
```

**Why `localDay` is stored rather than computed:** grouping by a local calendar day
across a DST boundary, a timezone change, or a travel trip is a subtle correctness
problem that is expensive to get right at query time. Storing the local-day key at
write time freezes the user's day grouping at the moment of recording. If the user
travels, past days keep their original grouping, which is the behaviour people
expect from a personal log.

## Structured Tables

Some things are not scalars. These get their own tables.

### Workouts

```dart
class Workouts extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime()();
  IntColumn get durationSeconds => integer()();
  RealColumn get distanceMeters => real().nullable()();
  IntColumn get calories => integer().nullable()();
  IntColumn get averageHeartRate => integer().nullable()();
  TextColumn get source => text()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

### Sleep sessions

```dart
class SleepSessions extends Table {
  TextColumn get id => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime()();
  IntColumn get durationMinutes => integer()();
  IntColumn get deepMinutes => integer().nullable()();
  IntColumn get remMinutes => integer().nullable()();
  IntColumn get lightMinutes => integer().nullable()();
  IntColumn get awakeMinutes => integer().nullable()();
  TextColumn get source => text()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

Nullable stage columns are meaningful: absent stages mean "not measured", which is
different from "zero minutes in deep sleep".

### Meals

```dart
class Meals extends Table {
  TextColumn get id => text()();
  TextColumn get mealType => text()();
  TextColumn get name => text()();
  IntColumn get calories => integer().nullable()();
  RealColumn get proteinG => real().nullable()();
  RealColumn get carbsG => real().nullable()();
  RealColumn get fatG => real().nullable()();
  DateTimeColumn get eatenAt => dateTime()();
  DateTimeColumn get localDay => dateTime()();
  TextColumn get source => text()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

## Sync Tables

### Outbox

Every local write enqueues an operation here in the same transaction as the write
itself. This is what makes the sync crash-safe: the operation and the data are
committed atomically.

```dart
class SyncOutbox extends Table {
  TextColumn get id => text()();
  TextColumn get operation => text()();   // upsert | delete
  TextColumn get entityType => text()();  // measurements | workouts | ...
  TextColumn get entityId => text()();
  TextColumn get payload => text()();     // JSON
  DateTimeColumn get queuedAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  BoolColumn get isProcessing => boolean().withDefault(const Constant(false))();
}
```

`isProcessing` is the claim flag that stops two concurrent sync runs from
processing the same row. Claim with a conditional update, not a read-then-write.

### Remote change log

```dart
class RemoteChanges extends Table {
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text()();
  DateTimeColumn get serverTimestamp => dateTime()();
  TextColumn get payload => text()();
  BoolColumn get isApplied => boolean().withDefault(const Constant(false))();
}
```

## Soft Deletes

Every user-facing table has `deletedAt`. Deletion sets it; queries filter
`deletedAt IS NULL`. The sync layer turns a local delete into a `delete` operation
in the outbox and a remote delete into a tombstone row locally, so a delete
propagates in both directions and can be undone within a grace window.

**Never `DELETE FROM`** a table holding user health history. The exception is the
outbox and remote-change tables, which are transient machinery and can be purged
on a schedule.

## Migration Rules

1. **Bump `schemaVersion`** in `AppDatabase`.
2. **Write the migration** in `onUpgrade`, guarded by `if (from < N)`.
3. **Add an index** in a migration with `customStatement`, not in `onCreate` only —
   existing installs need it too.
4. **Never change an existing migration.** Installed apps have already run it.
5. **Never change the meaning of an existing column.** Add a new column and
   backfill.
6. **Test every step.** Use drift's `stepByStep` migration test helper with a
   schema snapshot per version.

```dart
MigrationStrategy get migration => MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
        await _createIndexes();
      },
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.addColumn(measurements, measurements.localDay);
        }
        if (from < 3) {
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_measurements_local_day '
            'ON measurements(local_day)',
          );
        }
      },
    );
```

## Backup and Export

A personal health database is the user's most valuable data. The app should be
able to export everything as JSON or CSV. That means:

- Every table has a stable `wireName`-based JSON representation.
- Exports include the schema version.
- Import validates the schema version before writing anything.

This is also the safety net that makes aggressive schema changes acceptable:
a user can export, upgrade, and import.

## Seeding

Do not seed fake health data into the production database. If demo data is needed
for screenshots or manual testing, put it behind a `--dart-define=SEED_DEMO=true`
flag and a separate seeding path that is clearly marked. A health app that shows
fake data mixed with real data is dangerous.
