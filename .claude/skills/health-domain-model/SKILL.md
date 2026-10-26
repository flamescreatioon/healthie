---
name: health-domain-model
description: Defines Healthie's health-tracking domain vocabulary, the canonical metric catalog with units and clinical ranges, the drift storage schema for time-series health data, and the mapping between Healthie's metric types and Android Health Connect data types. This skill should be used whenever work involves naming or adding a health metric, changing how a value or unit is represented, designing or migrating the database schema, deciding what counts as a distinct measurement versus a derived summary, or when a question arises about what a term like "daily average", "measurement", or "summary" means in this codebase. Use it before adding any new tracked metric or changing the database schema.
---

# Healthie Domain Model

Healthie tracks personal health data. The domain has precise vocabulary, and using
it consistently is what keeps a year of personal health history coherent across
manual entry, Health Connect imports, and cloud sync.

## Core Vocabulary

| Term | Meaning | Not to be confused with |
|---|---|---|
| **Measurement** | A single recorded value for one metric at one instant (weight = 78.4 kg at 07:30). | A **summary** (aggregates over a window). |
| **Series** | An ordered set of measurements of the same metric type. | A **summary**. |
| **Summary** | A derived aggregate over a time window (daily step total, 7-day average weight). | Raw data. Never persisted as authoritative. |
| **Source** | Where a measurement came from: `manual`, `healthConnect`, `imported`, `derived`. | The sync status. |
| **Sync state** | Whether a record has reached the server. Independent of `source`. | `source`. |
| **Metric type** | The kind of thing measured (weight, steps, sleep…). | A **unit**. |
| **Unit** | The scale of a measurement (kg, lb, bpm, minutes). Belongs to the value, not the screen. | The metric type. |
| **Local day** | The user's day in their own timezone, used for all daily rollups. | UTC day. |
| **Recorded at** | When the measurement happened. | When it was entered. |

**The local-day rule is the most consequential decision in this domain.** Daily
summaries group by the user's local calendar day, not UTC. A measurement at
23:30 local belongs to that local day even though it is the next day in UTC. Store
`recordedAt` in UTC and convert to local at the grouping boundary. A dashboard that
shows the wrong day's steps because of a timezone boundary is a bug users cannot
explain away.

## The Three Timestamp Fields

Distinguish these explicitly — conflating them causes real bugs:

| Field | Meaning | Set by |
|---|---|---|
| `recordedAt` | When the thing happened | The event (manual entry, Health Connect record) |
| `createdAt` | When the row was written to this device | The app, on insert |
| `updatedAt` | When the row was last modified | The app, on every write |

A user correcting yesterday's weight edits the record hours later: `recordedAt`
stays, `updatedAt` changes. Health Connect imports arrive with a `recordedAt` in
the past but `createdAt` now. Sync conflict resolution compares `updatedAt`.

## Source and Sync Are Independent

A measurement can be `source: healthConnect` and `isSynced: false` (imported from
the device but not yet uploaded). It can be `source: manual` and `isSynced: true`.

Keep them in separate columns. Merging them into one "status" field makes
"should this be uploaded?" and "where did this come from?" mutually exclusive and
breaks the sync queue.

## Metric Types

`MetricType` is a closed enum. Every metric type declares:

- a stable `wireName` (a snake_case string, stable across releases and used in the
  database and the API — **never** the Dart enum name, which can be renamed),
- a canonical storage unit,
- the set of units the user may enter in,
- a plausible range for validation,
- an optional Health Connect data type mapping.

Add new metrics by extending the enum and the catalog reference together. Never
rename an existing `wireName` — old synced records reference it forever.

## Unit Handling

**Store canonically.** Weight is stored in kg. Blood pressure is stored in mmHg.
Only the entry form and the display layer deal in the user's preferred unit.

**Convert at the boundary, once.** The form converts the entered value to canonical
before saving. The display layer converts canonical → display. Never store a
display value.

**Never let a unitless number into the database.** A `RealColumn` with no
accompanying unit column is a bug waiting to happen. The measurement table
carries the unit explicitly even though it is derivable from the metric type —
the explicit column makes queries and migrations unambiguous.

**Prefer the `Unit` value object** over raw strings. A sealed class or an enum with
a conversion factor per unit prevents "70" meaning kg in one place and lb in
another.

## Validation Ranges

Ranges are for catching typos, not for medical judgement:

- **Weight**: 20–400 kg (44–880 lb). Wider is fine.
- **Heart rate**: 20–250 bpm resting; 20–250 while active.
- **Blood pressure**: systolic 50–260, diastolic 30–160 mmHg.
- **Body temperature**: 30–45 °C (86–113 °F).
- **SpO₂**: 50–100 %.
- **Sleep**: 0–24 h.
- **Water**: 0–20 L per day.
- **Steps**: 0–200 000 per day.

Reject outside-range input with a clear message. Do not silently clamp — clamping
turns a typo into a plausible-looking wrong record.

## Health Connect Mapping

Health Connect data types map onto Healthie's metric types, but the mapping is
**not one-to-one**. A Health Connect exercise session maps to a Healthie workout
session plus derived duration/distance/calorie metrics. A Health Connect sleep
session maps to a Healthie sleep session plus a derived sleep-duration metric.

**Health Connect is read-only for this app's history.** The user chose manual entry
as the primary input; Health Connect supplies step count, heart rate, sleep, and
workouts as a *second source*. Healthie's own records are authoritative when both
sources have data for the same moment.

Never write a Health Connect record back into Health Connect from a manual entry.
That would create duplicate data in the user's Health app and is a policy violation.

## Schema Rules

- **Time-series tables are append-friendly.** Index `recordedAt` on every table the
  dashboard queries.
- **Store `localDay` as a denormalized column** (`DateTime` at local midnight) for
  tables queried by day. Grouping by a computed local day at query time is correct
  but slow, and gets subtly wrong across DST. Store both; use the stored one for
  rollups.
- **Never hard-delete user data.** Soft-delete with `deletedAt` so a deletion can
  sync and be undone. A personal tracker with a sync backend needs tombstones.
- **Migrations are permanent.** Every schema change needs a migration and a test.
  A personal health database holds years of irreplaceable history.
- **Use `real` for measurements, `integer` for counts and durations.** Store
  durations as seconds or minutes as integers — never as fractional hours.

## Reference Files

- `references/metric-catalog.md` — the canonical metric list with units, ranges,
  and Health Connect data-type mappings. Read this before adding a metric.
- `references/storage-schema.md` — the Drift table definitions and migration rules.
- `references/glossary.md` — full domain glossary and the ADR conventions for
  recording decisions.
