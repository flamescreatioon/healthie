# Phase 2 — Schema Migrations (PostgreSQL)

One migration file each. Never edit a shipped migration — add a new one.

## users (+ Sanctum)

Laravel default `users` + Sanctum `personal_access_tokens` migration.
Add `display_name`, `unit_preferences JSON`, `deleted_at` (if soft-deleting users).

## measurements

`id uuid PK` (client-generated) — use `$table->uuid('id')->primary()`;
`user_id FK cascadeOnDelete`; `metric_type text`; `value double`;
`unit text`; `secondary_value/secondary_unit`, `tertiary_value/tertiary_unit`
(BP composite, ADR-0001); `recorded_at timestamptz`; `local_day date`;
`source enum(manual,health_connect,imported,derived)`; `context_json jsonb NULL`;
`client_updated_at timestamptz` (device clock — LWW compare);
`server_updated_at timestamptz` (server clock — pull cursor);
timestamps + `SoftDeletes` (tombstone).

Indexes: `(user_id, local_day)`, `(user_id, metric_type, recorded_at DESC)`,
`(user_id, server_updated_at)`.

## workouts / sleep_sessions / meals

Same ownership/clock/tombstone columns, own domain fields. Port field lists
from `health-cloud-sync/references/backend-schema.md` into Laravel migrations:

- `workouts`: `workout_type, started_at, ended_at, duration_seconds int, distance_meters double NULL, calories int NULL, average_heart_rate int NULL, source`
- `sleep_sessions`: `started_at, ended_at, duration_minutes int, deep/rem/light/awake_minutes int NULL, source`
- `meals`: `meal_type, name, calories int NULL, protein/carbs/fat_g double NULL, eaten_at, local_day date, source`

## profiles / goals / reminders

Per `docs/api-contract.md` §2: profile (name, units, targets); goals
(metric type + target + unit + optional date); reminders
(kind + metric + local time + enabled).

## Review rules

- Durations integer seconds/minutes; measurements double; counts integer.
- `unit` explicit on every row; canonical units only (kg, cm, mmHg, °C).
- `local_day` never recomputed server-side.
- `metric_type` wire names match `health-domain-model/references/metric-catalog.md`.

**Done when:** `migrate:fresh` builds all tables + indexes.

Next: [Auth & authorization](./03-authorization-verification.md).
