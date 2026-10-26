# Architecture

Healthie is a **feature-first, layered, offline-first** Flutter application.

---

## 1. The layers

```
                ┌───────────────────────────────┐
                │          presentation          │
                │  screens · widgets · providers │
                └───────────────┬───────────────┘
                                │ depends on
                ┌───────────────▼───────────────┐
                │            domain              │
                │  models · interfaces · rules   │
                └───────────────▲───────────────┘
                                │ implements
                ┌───────────────┴───────────────┐
                │             data               │
                │  drift tables · daos · repos   │
                └───────────────────────────────┘
```

**The rule:** dependencies point inward. A presentation file never imports
`data`. A domain file never imports `data`, `presentation`, or the
infrastructure in `core/database` and `core/sync`.

`lib/app/providers.dart` is the composition root. It is the single place where
concrete implementations are bound to abstractions, which is what keeps the
rest of the app free of `data` imports and what makes every dependency
replaceable with a fake in a test.

### Why this matters here

A health app has several data sources — manual entry today, Health Connect
tomorrow, a cloud backend the day after — and all of them must present
identically to the UI. Keeping the source behind a domain interface is what
makes that possible, and what makes the whole feature testable without a
device.

### Enforcement

`import_linter` is no longer published on pub.dev, so the rule is enforced by
a dependency-free script instead:

```bash
dart run tool/check_layering.dart
```

It checks three things:

1. `presentation` does not import `data`.
2. `domain` does not import `data`, `presentation`, or `core/database` /
   `core/sync`.
3. The core packages the domain layer is allowed to depend on (`core/units`,
   `core/utils`, `core/error`) are genuinely pure — they may import only
   `dart:` and `package:flutter/foundation.dart`.

---

## 2. State management

Riverpod 3.4.3, with three provider kinds:

| Kind | Used for | Example |
|---|---|---|
| `Provider` | A service that never changes | `measurementRepositoryProvider` |
| `StreamProvider` | Reactive data from a repository stream | `allMeasurementsProvider` |
| `FutureProvider` | A one-shot read | `goalsProvider` |

Rules:

- Providers live next to the feature they serve, under
  `features/<feature>/presentation/providers/`.
- Screen-scoped state is `autoDispose` so watchers are released on
  navigation.
- A provider that needs feature scope takes a **value-typed** argument
  (`MetricRangeQuery`), never a widget reference or a closure over a
  `BuildContext`.
- Tests override providers with `ProviderScope(overrides: [...])`. Global
  state is never mutated.

There is no `get_it`, no `injectable`, and no `flutter_bloc`. One dependency
injection mechanism is one less thing to learn.

---

## 3. Navigation

`go_router` 18.1.1, configured once in `lib/app/router.dart`.

- Five destinations live in a `StatefulShellRoute.indexedStack`, so each tab
  keeps its own scroll position and back stack.
- The two entry screens are top-level routes pushed over the shell.
- The bottom navigation bar is hand-composed rather than `NavigationBar`,
  because Material's bar cannot host a raised centre action.

---

## 4. Storage

### The measurements table

One table with a metric discriminator, rather than one table per metric. This
keeps queries uniform, makes "everything recorded on this day" a single scan,
and lets the sync layer treat every metric identically.

| Column | Type | Meaning |
|---|---|---|
| `id` | TEXT PK | Device-generated identifier |
| `metric_type` | TEXT | The metric's wire name |
| `value` | REAL | The primary value, in canonical units |
| `unit` | TEXT | The unit of `value` |
| `secondary_value` | REAL? | Diastolic (BP) or body fat (weight) |
| `secondary_unit` | TEXT? | |
| `tertiary_value` | REAL? | Pulse (BP) or waist (weight) |
| `tertiary_unit` | TEXT? | |
| `recorded_at` | DATETIME | When it happened, UTC |
| `local_day` | DATETIME | Local midnight of the day it belongs to |
| `created_at` | DATETIME | When the row was written |
| `updated_at` | DATETIME | When the row was last modified |
| `source` | TEXT | `manual`, `health_connect`, `imported`, `derived` |
| `is_synced` | BOOLEAN | Whether it has reached the server |
| `deleted_at` | DATETIME? | Tombstone |
| `context_json` | TEXT? | Posture, arm, circumstances, notes, device |

Indexes: `local_day`, `(metric_type, local_day)`, `recorded_at`.

### The local-day rule

Daily rollups group by the user's **own calendar day**, never by UTC. A
reading taken at 23:30 local belongs to that local day even though it is
already the next day in UTC. The day is **stored** at write time rather than
computed at query time, which freezes the grouping at the moment of recording:
if the user travels, past days keep their original grouping.

All day arithmetic is calendar-based, not 24-hour-based. `DateTime(y, m, d + 1)`
is used rather than `add(Duration(days: 1))`, because on a daylight-saving
day the latter lands at 01:00 the next morning rather than midnight. See
[ADR 0002](adr/0002-local-day-grouping.md).

### Timestamps

Three timestamps, kept distinct:

| Field | Meaning | Set by |
|---|---|---|
| `recorded_at` | When the measurement happened | The event |
| `created_at` | When the row was written here | The app, on insert |
| `updated_at` | When the row was last modified | The app, on every write |

Correcting yesterday's weight changes `updated_at` and leaves `recorded_at`
alone. Sync conflict resolution compares `updated_at`.

### Soft deletes

`deleted_at` is set; the row is never removed. Queries filter
`deleted_at IS NULL`. A deletion enqueues a `delete` operation in the outbox,
and the snackbar offers an undo.

### Other tables

- `profiles` — the local profile: name, units, clinician-provided targets.
- `goals` — user-defined targets per metric.
- `reminders` — scheduled checks: kind, metric, time of day, enabled.
- `sync_outbox` — the write-ahead queue.

---

## 5. The sync outbox

Every local write enqueues an operation in the **same transaction** as the
write itself:

```
transaction {
  upsert measurement
  enqueue { operation: 'upsert', entityId, payload }
}
```

That atomicity is the whole point: a crash can never leave a saved reading
without a pending upload, and a failed upload never discards a local record.

The outbox holds at most one operation per entity, keyed by entity id. A
`delete` therefore replaces a pending `upsert` for the same record — a
tombstone always wins over an upload that has not gone out yet.

`is_processing` is the claim flag that stops two concurrent sync runs from
processing the same row. It is claimed with a conditional `UPDATE`, never a
read-then-write.

The outbox and the remote-change table are the only tables that may ever be
purged. Everything else is user history.

---

## 6. Error handling

A sealed `AppFailure` hierarchy in `lib/core/error/app_failure.dart`:

```
AppFailure
├── ValidationFailure   the user entered something unacceptable
├── StorageFailure      the database could not complete an operation
├── NetworkFailure      the device could not reach the backend
├── PermissionFailure   a platform permission was not granted
└── SyncFailure         an upload failed and will be retried
```

Repositories translate low-level exceptions into these. Presentation code
never sees a `SocketException`, and a raw exception string is never rendered
to the user: failures are mapped to human copy at the presentation layer.

---

## 7. Domain vocabulary

| Term | Meaning |
|---|---|
| **Measurement** | One recorded value for one metric at one instant |
| **Reading** | A measurement with its context (posture, arm, notes) |
| **Summary** | A derived aggregate over a window; never persisted as authoritative |
| **Local day** | The user's calendar day, used for every daily rollup |
| **Source** | Where a measurement came from: `manual`, `healthConnect`, … |
| **Sync state** | Whether a record has reached the server — independent of source |

Source and sync state are separate columns. A Health Connect import can be
unsynced; a manual entry can be synced. Merging them into one "status" field
makes "should this be uploaded?" and "where did this come from?" mutually
exclusive.

---

## 8. Metrics and units

`MetricType` is a closed enum. Each entry declares a stable `wireName`, a
canonical unit, the units the user may enter in, a plausible range, and a
precision.

Values are stored canonically: kilograms for mass, centimetres for length,
millimetres of mercury for pressure, degrees Celsius for temperature. The
entry form converts once on save; the display layer converts once on render.
A unitless number never enters the database.

See [ADR 0001](adr/0001-composite-blood-pressure-record.md) for why a blood
pressure reading occupies one row rather than two.
