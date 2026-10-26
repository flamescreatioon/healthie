# Healthie Glossary and Decision Records

## Glossary

Terms are listed alphabetically. When one of these words appears in code, a class
name, a column name, or a variable name, it means what it says here.

### Activity

**Active calories** — Energy burned through movement, excluding basal metabolic
rate. Distinct from total calories.

**Basal metabolic rate (BMR)** — Energy burned at rest. Derived, not entered.
Healthie computes BMR from profile data using a published formula (Mifflin-St Jeor
or Harris-Benedict). The formula used must be recorded in the code that computes it
and surfaced in the UI when a BMR-based estimate is shown.

**Distance** — Linear distance travelled. Stored in metres. Derived from steps only
when the user has supplied a stride length; otherwise it stays null rather than
being guessed.

**Exercise session** — A discrete period of physical activity with a start, an end,
and a type. Corresponds to a Health Connect `EXERCISE_SESSION`.

**Steps** — A count of steps. Stored as an integer per measurement period.

### Body

**Body fat percentage** — The proportion of body mass that is fat. Either measured
by the user or entered manually. Not estimated by the app.

**Lean mass** — Body mass excluding fat. Derived from weight and body fat.

### Data provenance

**Derived** — A value computed by the app from other recorded data (e.g. a 7-day
average, an estimated BMR). Derived values are never authoritative and can always
be recomputed.

**Health Connect source** — Data imported from Android Health Connect. Read-only
within Healthie.

**Imported** — Data brought in from a file, another app, or a bulk export.

**Manual source** — Data the user typed in.

**Source** — The provenance of a measurement. One of `manual`, `healthConnect`,
`imported`, `derived`. Independent of sync state.

**Sync state** — Whether a record has reached the server. Independent of source.

### Records

**Measurement** — One recorded value for one metric at one instant.

**Meal** — A structured eating event with a type, a name, and optional nutrition.

**Series** — An ordered set of measurements of the same metric type.

**Sleep session** — A structured period of sleep with optional stage breakdown.

**Summary** — An aggregate computed over a time window. Never persisted as
authoritative; always recomputable.

**Workout** — A structured record of physical activity.

### Time

**Created at** — When the row was written to this device.

**Local day** — The user's calendar day in their own timezone. All daily rollups
group by this. Computed from `recordedAt` and the device timezone at write time.

**Recorded at** — When the thing being recorded actually happened.

**Updated at** — When the row was last modified. Used for sync conflict resolution.

**UTC** — The storage timezone for all timestamps. Local time is a rendering
concern only.

### Units

**Canonical unit** — The unit a metric is stored in (kg for weight, mmHg for
blood pressure, metres for distance). Fixed by the metric catalog.

**Display unit** — The unit the user sees, chosen in settings (kg or lb).

**Entry unit** — A unit the user may type in. The form converts to canonical on
save.

### Wellness

**Mood** — A 1–5 subjective score where 5 is best.

**Energy** — A 1–5 subjective score where 5 is best.

**Stress** — A 1–5 subjective score where 5 is worst (most stress).

**Pain** — A 0–10 score where 10 is worst. Kept on a separate scale from the
1–5 scores and never averaged with them.

**Wellness score** — A composite 0–100 score. If implemented, its formula must be
documented in code and disclosed in the UI. A composite score that hides its
inputs is worse than showing the inputs separately, because users will treat it as
a clinical signal.

## Decision Records (ADRs)

Record architectural decisions that are expensive to reverse, that a future
contributor would otherwise re-litigate, or where the reasoning is not visible in
the code. Store them in `docs/adr/`, numbered and immutable once accepted.

### Format

```markdown
# ADR 0007: Store measurements in a single polymorphic table

- Status: Accepted
- Date: 2026-10-22

## Context

Healthie tracks ~30 metric types. Most are scalar values over time. A separate
table per metric would mean a separate DAO, repository method, sync handler, and
migration for each.

## Decision

Use one `measurements` table with a `metric_type` discriminator and a
`local_day` column. Structured records (workouts, sleep sessions, meals) get
their own tables.

## Consequences

- One query shape for "all metrics on this day".
- Uniform sync handling for scalar metrics.
- Type safety within a metric type is a domain-layer concern, not a schema one.
- Adding a metric needs no migration.
- Metrics needing multiple values at one instant (blood pressure) need either a
  separate table or a paired-value encoding; blood pressure uses two measurements
  (systolic and diastolic) sharing a `recordedAt`.
```

### Decisions worth recording

- The local-day grouping rule.
- Single polymorphic measurement table vs. per-metric tables.
- Supabase/Postgres as the backend vs. Firebase vs. a bespoke server.
- Last-write-wins conflict resolution vs. field-level merge.
- Treating Health Connect as read-only.
- Whether BMR/derived wellness scores are shown at all.
- Storing local-day keys at write time vs. computing them at query time.
- Soft-delete vs. hard-delete.

### When not to write an ADR

Do not record decisions that are easily reversible, that the code already states
plainly, or that are purely a matter of taste. An ADR that documents a null result
is wasted maintenance.
