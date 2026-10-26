# Architecture Recipes

Copy-paste starting points for Healthie. Adjust names to the feature; keep the
shapes.

## New Feature Checklist

1. **Domain model** — `features/<f>/domain/<f>.dart` with `freezed` + `fromJson`.
2. **Repository interface** — `features/<f>/domain/<f>_repository.dart`.
3. **Drift table** — `core/database/tables/<f>_table.dart` (if it needs storage).
4. **DAO** — `features/<f>/data/<f>_dao.dart`.
5. **Repository implementation** — `features/<f>/data/<f>_repository_impl.dart`,
   implementing the domain interface and mapping Drift rows → domain models.
6. **Providers** — `features/<f>/presentation/providers/<f>_providers.dart`.
7. **Screen + widgets** — `features/<f>/presentation/`.
8. **Route** — register in `app/router.dart`.
9. **Tests** — `test/features/<f>/` mirroring the source layout.

Do steps 1 and 2 before 3. Designing the storage schema first and reverse-engineering
the domain model from it is how health schemas end up with awkward `value` /
`value2` columns.

## Freezed Domain Model

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part '<f>.freezed.dart';
part '<f>.g.dart';

@freezed
class FoodEntry with _$FoodEntry {
  const factory FoodEntry({
    required String id,
    required String name,
    required int caloriesKcal,
    required DateTime eatenAt,
    @Default(MeasurementSource.manual) MeasurementSource source,
    @Default(false) bool isSynced,
  }) = _FoodEntry;

  factory FoodEntry.fromJson(Map<String, dynamic> json) =>
      _$FoodEntryFromJson(json);
}
```

## Sealed Failure

```dart
sealed class AppFailure implements Exception {
  const AppFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure([super.message = 'Could not reach the server.']);
}

final class StorageFailure extends AppFailure {
  const StorageFailure([super.message = 'Could not read local data.']);
}

final class PermissionFailure extends AppFailure {
  const PermissionFailure([super.message = 'Permission was not granted.']);
}

final class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message);
}
```

## Repository Interface and Implementation

```dart
// domain/log_repository.dart
abstract interface class LogRepository {
  Stream<List<WeightEntry>> watchWeight({required DateTimeRange range});
  Future<void> saveWeight(WeightEntry entry);
  Future<void> deleteWeight(String id);
}

// data/log_repository_impl.dart
class LogRepositoryImpl implements LogRepository {
  LogRepositoryImpl(this._dao, this._outbox);

  final LogDao _dao;
  final SyncOutbox _outbox;

  @override
  Stream<List<WeightEntry>> watchWeight({required DateTimeRange range}) =>
      _dao.watchWeight(range).map(
            (rows) => rows.map((r) => r.toDomain()).toList(growable: false),
          );

  @override
  Future<void> saveWeight(WeightEntry entry) async {
    await _dao.transaction(() async {
      await _dao.upsert(entry);
      await _outbox.enqueue(SyncOp.upsert, 'weight', entry.id, entry.toJson());
    });
  }

  @override
  Future<void> deleteWeight(String id) =>
      _dao.transaction(() => _outbox.enqueue(SyncOp.delete, 'weight', id, {}));
}
```

## Drift Table

```dart
class WeightEntries extends Table {
  TextColumn get id => text()();
  RealColumn get value => real()();
  TextColumn get unit => text().withLength(min: 1, max: 8)();
  DateTimeColumn get recordedAt => dateTime()();
  TextColumn get source => text()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
```

Index anything queried by time:

```dart
class WeightEntries extends Table {
  // ...
  @override
  List<Set<Column>> get uniqueKeys => [];
}
```

Add an index in a migration for `recordedAt` — every dashboard query filters on it.

## Provider Patterns

```dart
// A service that never changes
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

// Reactive data
final weightStreamProvider = StreamProvider.family<List<WeightEntry>, DateTimeRange>(
  (ref, range) {
    final repo = ref.watch(logRepositoryProvider);
    return repo.watchWeight(range: range);
  },
);

// Mutable async state
class AuthController extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async => const AuthState.signedOut();

  Future<void> signIn(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _signIn(email, password));
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthState>(AuthController.new);
```

## Riverpod Override in Tests

```dart
ProviderScope(
  overrides: [
    logRepositoryProvider.overrideWithValue(FakeLogRepository()),
  ],
  child: const TestApp(),
)
```

## Drift Query Patterns

```dart
// Reactive, filtered, ordered
Stream<List<WeightEntryData>> watchWeight(DateTimeRange range) {
  final query = select(weightEntries)
    ..where((t) => t.recordedAt.isBetweenValues(range.start, range.end))
    ..orderBy([(t) => OrderingTerm.desc(t.recordedAt)]);
  return query.watch();
}

// Aggregate for a dashboard
Future<double?> latestWeight() async {
  final query = select(weightEntries)
    ..orderBy([(t) => OrderingTerm.desc(t.recordedAt)])
    ..limit(1);
  final row = await query.getSingleOrNull();
  return row?.value;
}

// Sum over a day
Future<int> stepsOn(DateTime day) async {
  final sum = weightEntries.value.sum();
  final query = selectOnly(weightEntries)
    ..addColumns([sum])
    ..where(weightEntries.recordedAt.isBetweenValues(dayStart, dayEnd));
  return (await query.getSingle()).read(sum) ?? 0;
}
```

## go_router

```dart
final router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final signedIn = authState.valueOrNull?.isSignedIn ?? false;
    final goingToAuth = state.matchedLocation == '/sign-in';
    if (!signedIn && !goingToAuth) return '/sign-in';
    if (signedIn && goingToAuth) return '/';
    return null;
  },
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(shell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/', builder: (c, s) => const DashboardScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/log',
            builder: (c, s) => const LogScreen(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/metric/:type',
            builder: (c, s) => MetricDetailScreen(
              type: MetricType.values.byName(s.pathParameters['type']!),
            ),
          ),
        ]),
      ],
    ),
  ],
);
```

## Drift Migration

```dart
MigrationStrategy get migration => MigrationStrategy(
      onCreate: (m) async => m.createAll(),
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.addColumn(weightEntries, weightEntries.unit);
        }
        if (from < 3) {
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_weight_recorded_at '
            'ON weight_entries(recorded_at)',
          );
        }
      },
    );
```

Bump `schemaVersion` and write a test for every migration step. A health database
holds years of personal history — losing it to a failed migration is unacceptable,
and there is no "reset my account" escape hatch for a personal tracker.
