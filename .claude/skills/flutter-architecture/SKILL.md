---
name: flutter-architecture
description: Defines and enforces the Healthie Flutter app's feature-first layered architecture — Riverpod 3 state management, repository pattern over Drift, go_router navigation, and dependency boundaries between domain, data, and presentation layers. This skill should be used whenever work adds a feature, introduces a new screen or route, creates or refactors a provider/controller, designs a repository or data-access layer, wires dependencies, or when a question arises about where a class belongs, how state flows, or how a feature should be structured. Use it before writing the first file of any new feature.
---

# Healthie Architecture

Healthie is a **feature-first, layered** Flutter app with **offline-first** data
flow. The local Drift database is the source of truth for the UI; the cloud backend
is a replication target, never a prerequisite for showing the user their own data.

## Layering Rule

Each dependency may only point inward:

```
presentation  →  domain  ←  data
```

- **presentation** — widgets, screens, Riverpod providers. Knows about domain
  interfaces. Never imports from `data/`.
- **domain** — models, repository *interfaces*, pure business rules. Depends on
  nothing but `dart:*` and the Flutter SDK (for `@immutable`-style annotations).
  No Drift, no Supabase, no `flutter_riverpod`.
- **data** — Drift tables/DAOs, repository *implementations*, DTOs, sync adapters.
  Implements domain interfaces.

The dependency rule is enforced by the import linter in `analysis_options.yaml`.
Run `flutter analyze` — a violation is a build failure, not a style nit.

**Why it matters here:** a health app has several data sources (manual entry,
Health Connect, cloud) that must present identically to the UI. Keeping the source
behind a domain interface is what lets a Health Connect read and a manual entry be
indistinguishable downstream, and what makes the whole app testable without a device.

## Feature-First Layout

```
lib/
  main.dart                      # entrypoint: init DB, auth, sync; runApp
  app/
    app.dart                     # MaterialApp.router, theme, locale
    router.dart                  # go_router configuration
    theme/
      app_theme.dart
      app_colors.dart
      app_typography.dart
      app_spacing.dart
  core/
    database/
      app_database.dart          # Drift database class
      app_database.g.dart        # generated
      tables/                    # table definitions
      migrations.dart
    error/
      app_failure.dart           # sealed failure hierarchy
    network/
      connectivity_service.dart
    sync/
      sync_service.dart
      sync_queue.dart
    utils/
      date_utils.dart
      unit_conversion.dart
  features/
    metrics/
      data/
        metric_dao.dart
        metric_repository_impl.dart
      domain/
        metric.dart              # freezed model
        metric_repository.dart    # abstract interface
        metric_query.dart
      presentation/
        metrics_screen.dart
        providers/metric_providers.dart
        widgets/
    logging/                     # manual entry feature
    health_connect/
    workouts/
    sleep/
    dashboard/
    settings/
  shared/
    widgets/
    formatters/
    form/
```

A feature that is not yet built should not get an empty directory. Create the
folder when the first real file goes in.

## Domain Models

Use `freezed` for every domain model. Freezing gives `copyWith`, value equality,
and pattern matching — all three are used constantly in a health app (merging
readings, comparing for sync conflicts, exhaustive `switch` over metric types).

```dart
@freezed
class Measurement with _$Measurement {
  const factory Measurement({
    required String id,
    required MetricType type,
    required double value,
    required DateTime recordedAt,
    required MeasurementSource source,
    @Default(MeasurementSource.manual) bool isSynced,
  }) = _Measurement;

  factory Measurement.fromJson(Map<String, dynamic> json) =>
      _$MeasurementFromJson(json);
}
```

Rules for domain models:

- **Immutable and non-nullable.** Use `@Default(...)` for optional fields rather
  than nullable fields with null-checks scattered through the UI.
- **`double` for values, plus a separate `unit`.** Never store "78.4" without
  knowing it is kg or lb. Unit lives with the value, not in the UI.
- **`DateTime` in UTC.** Convert to local only at render time. A weight logged at
  23:30 local on a DST boundary must not shift a day when synced.
- **IDs are strings** (`uuid`-style), generated on the device. The server must
  never be the ID authority for locally-created records — the device may be offline
  for days.
- **No `DateTime.now()` inside a model.** Pass the timestamp in.

## Repositories

A repository interface lives in `domain/`, the implementation in `data/`. The
interface is written in terms of the domain, never in terms of Drift or Supabase.

```dart
abstract interface class MetricRepository {
  Stream<List<DailySummary>> watchSummaries({required DateTimeRange range});
  Future<List<Measurement>> measurementsFor(MetricType type, DateTimeRange range);
  Future<void> save(Measurement measurement);
  Future<void> delete(String id);
}
```

Rules:

- **Queries return domain objects, never Drift rows.** Drift's generated data
  classes (`MeasurementData`) stay inside `data/`. Mapping happens in the
  repository implementation.
- **Watch methods return `Stream`** for anything the UI displays, so the UI
  updates automatically when the DB changes. Drift's reactive queries make this
  natural.
- **The repository is the only thing that knows about sync.** It writes to the
  local DB and enqueues a sync record; it does not call Supabase directly.
- **The repository is the only thing that knows about Health Connect.** The UI
  asks the repository for data, never the Health Connect client.

## State Management with Riverpod 3

Riverpod 3.x (`flutter_riverpod` 3.4.3). Use three provider kinds:

1. **`Provider`** — a value or a service that never changes
   (e.g. `databaseProvider`, `settingsRepositoryProvider`).
2. **`StreamProvider`** — reactive data from a repository stream
   (e.g. `dailySummariesProvider(range)`).
3. **`AsyncNotifierProvider`** — mutable, async state with lifecycle
   (e.g. `authControllerProvider`, `syncControllerProvider`).

Rules:

- **Keep providers in `presentation/providers/`** next to the feature they serve,
  not in a global `providers/` dump.
- **Scope provider overrides in tests**, never mutate global state. A `ProviderScope`
  with `overrides:` is how tests inject a fake repository.
- **Do not create a provider per widget instance.** If a provider needs feature-
  scope, use `Provider.family` with a value-typed argument (a `MetricType`, a
  `DateTimeRange`) — not a widget reference or a closure over `BuildContext`.
- **`autoDispose` for screen-scoped state** so lists release their watchers when
  navigated away from. Keep `maintained` only for genuinely app-scoped state.
- **No `ref.watch` in `build` of a provider that also writes.** Use `ref.listen`
  where a side effect is needed.

## Navigation with go_router

`go_router` 18.1.1. Configure routes once in `app/router.dart`.

- **Declare routes as a typed map or a `GoRoute` list with named `path`s.**
  Never `context.push(MaterialPageRoute(...))` — that bypasses deep linking and
  the back stack semantics go_router provides.
- **Shell routes for the tab bar.** Use `StatefulShellRoute.indexedStack` so tab
  state is preserved when switching.
- **Pass parameters as named `pathParameters`** (`/metric/:type`) and read them with
  `state.pathParameters`. Parse them into typed values immediately.
- **Guards for auth.** A `redirect` on the router handles the signed-in vs
  signed-out decision in one place.
- **Deep links matter for a sync-backed app** — a health record shared via link
  should open the right record.

## Dependency Injection

Riverpod providers are the DI container. There is no `get_it` in this project.

Override a provider in `main.dart` (production) or in a test (fake):

```dart
ProviderScope(
  overrides: [
    metricRepositoryProvider.overrideWithValue(FakeMetricRepository()),
  ],
  child: const HealthieApp(),
)
```

Do not add `get_it`, `injectable`, or `flutter_bloc` to this project. One DI
mechanism is one less thing to learn.

## Error Handling

Use a **sealed `AppFailure` hierarchy** in `core/error/app_failure.dart`, not raw
exceptions thrown across layers.

```dart
sealed class AppFailure implements Exception {
  const AppFailure(this.message);
  final String message;
}

final class NetworkFailure extends AppFailure { ... }
final class StorageFailure extends AppFailure { ... }
final class PermissionFailure extends AppFailure { ... }
final class ValidationFailure extends AppFailure { ... }
```

- Repositories catch low-level exceptions (SQLite, HTTP) and translate them into
  `AppFailure`. Presentation code never sees a `SocketException`.
- **Never show a raw exception string to the user.** Map failures to human messages
  in the presentation layer.
- Health Connect permission denial is an expected state, not an error — surface it
  as an actionable prompt, not a failure banner.

## Offline-First Data Flow

Every write path follows this shape:

1. Write to the local Drift database inside a transaction.
2. Insert a row into the outbox/sync-queue table in the same transaction.
3. Update the UI from the reactive query — the write is already visible.
4. The sync service drains the outbox when connectivity and auth allow.

The network is never on the critical path of a user-visible write. A user logging
their weight on a train with no signal sees it saved instantly.

## Reference Files

- `references/recipes.md` — copy-paste starting points: new feature checklist,
  repository template, provider patterns, drift query patterns.
