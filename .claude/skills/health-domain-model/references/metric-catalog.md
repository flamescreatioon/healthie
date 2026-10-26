# Healthie Metric Catalog

The canonical list of tracked metrics. Read before adding a metric; extend this
file in the same change that adds the enum value.

Health Connect mappings assume the `health` package 13.3.2 API
(`HealthDataType.STEPS_COUNTER`, `HEART_RATE`, `SLEEP_SESSION`, `EXERCISE_SESSION`,
`DISTANCE`, `ACTIVE_CALORIES_BURNED`). Verify the exact enum names against the
package source before using them — `HealthDataType` names have changed across
major versions of that package.

## Body measurements

| Metric | `wireName` | Canonical unit | Entry units | Range | Health Connect |
|---|---|---|---|---|---|
| Weight | `weight` | kg | kg, lb | 20–400 kg | none |
| Height | `height` | cm | cm, in | 80–250 cm | none |
| Body fat | `body_fat` | % | % | 2–70 % | none |
| Waist | `waist_circumference` | cm | cm, in | 30–200 cm | none |
| Body temperature | `body_temperature` | °C | °C, °F | 30–45 °C | `TEMPERATURE` |

## Activity

| Metric | `wireName` | Canonical unit | Entry units | Range | Health Connect |
|---|---|---|---|---|---|
| Steps | `steps` | count | count | 0–200 000 /day | `STEPS_COUNTER` |
| Distance | `distance` | m | m, km, mi | 0–200 km /day | `DISTANCE` |
| Active calories | `active_calories` | kcal | kcal | 0–10 000 /day | `ACTIVE_CALORIES_BURNED` |
| Total calories | `total_calories` | kcal | kcal | 0–15 000 /day | `TOTAL_CALORIES_BURNED` |
| Exercise minutes | `exercise_minutes` | min | min | 0–1440 /day | `EXERCISE_SESSION` (derived) |

## Vitals

| Metric | `wireName` | Canonical unit | Entry units | Range | Health Connect |
|---|---|---|---|---|---|
| Heart rate | `heart_rate` | bpm | bpm | 20–250 | `HEART_RATE` |
| Resting heart rate | `resting_heart_rate` | bpm | bpm | 20–150 | `HEART_RATE` (derived) |
| Systolic BP | `blood_pressure_systolic` | mmHg | mmHg | 50–260 | none |
| Diastolic BP | `blood_pressure_diastolic` | mmHg | mmHg | 30–160 | none |

> **App-specific note:** Healthie's current implementation stores one blood
> pressure reading as a single row (`wireName: blood_pressure`) with
> `value` = systolic, `secondary_value` = diastolic, and `tertiary_value` =
> pulse. The component wire names above are retained in export and API
> payloads; they are never renamed.| Blood oxygen | `spo2` | % | % | 50–100 | `OXYGEN_SATURATION` |
| Respiratory rate | `respiratory_rate` | breaths/min | breaths/min | 5–60 | `RESPIRATORY_RATE` |

## Sleep and recovery

| Metric | `wireName` | Canonical unit | Entry units | Range | Health Connect |
|---|---|---|---|---|---|
| Sleep duration | `sleep_duration` | min | min, h | 0–1440 | `SLEEP_SESSION` (derived) |
| Time in bed | `time_in_bed` | min | min, h | 0–1440 | `SLEEP_SESSION` (derived) |
| Deep sleep | `deep_sleep` | min | min, h | 0–720 | `SLEEP_STAGE` (derived) |
| REM sleep | `rem_sleep` | min | min, h | 0–720 | `SLEEP_STAGE` (derived) |
| Light sleep | `light_sleep` | min | min, h | 0–720 | `SLEEP_STAGE` (derived) |
| Sleep score | `sleep_score` | points | — | 0–100 | none (derived) |

Sleep stages are only meaningful when the source provides stage data. Health
Connect supplies stages for many wearables; a manual entry supplies only a
duration. When stages are absent, leave them null — do not distribute the
duration across stages. Fabricated sleep stages are worse than missing ones.

## Nutrition and hydration

| Metric | `wireName` | Canonical unit | Entry units | Range | Health Connect |
|---|---|---|---|---|---|
| Calories consumed | `calories_consumed` | kcal | kcal | 0–15 000 /day | none |
| Protein | `protein` | g | g | 0–500 | none |
| Carbohydrates | `carbohydrates` | g | g | 0–1000 | none |
| Fat | `fat` | g | g | 0–500 | none |
| Water | `water` | ml | ml, L, fl oz | 0–20 000 /day | none |
| Alcohol | `alcohol` | g | g, drinks | 0–500 | none |

## Subjective

| Metric | `wireName` | Canonical unit | Entry units | Range | Health Connect |
|---|---|---|---|---|---|
| Mood | `mood` | score 1–5 | 1–5 | 1–5 | none |
| Energy | `energy` | score 1–5 | 1–5 | 1–5 | none |
| Stress | `stress` | score 1–5 | 1–5 | 1–5 | none |
| Pain | `pain` | score 0–10 | 0–10 | 0–10 | none |
| Note | `note` | text | — | ≤ 2000 chars | none |

Subjective scores use a consistent direction: **5 is always good** (best mood, most
energy, least stress). Pain is inverted so it cannot be averaged with the others —
keep pain on its own 0–10 scale and never include it in a "wellness score"
aggregate without explicitly inverting it first.

## Workout sessions

Workouts are structured records, not single measurements. Each workout carries:
type, start time, end time, duration, and optional distance, calories, average
heart rate, and average speed.

| Field | `wireName` | Unit |
|---|---|---|
| Workout type | `type` | enum (`running`, `walking`, `cycling`, `strength`, `swimming`, `yoga`, `other`) |
| Started at | `started_at` | UTC timestamp |
| Ended at | `ended_at` | UTC timestamp |
| Duration | `duration` | s |
| Distance | `distance` | m |
| Calories | `calories` | kcal |

A Health Connect `EXERCISE_SESSION` maps to a workout session. Map its activity
type onto the closest `workoutType`; keep the original Health Connect type string
in a `sourceMetadata` field so nothing is lost.

## Meals

Meals are structured records with a composition of items:

| Field | `wireName` | Unit |
|---|---|---|
| Eaten at | `eaten_at` | UTC timestamp |
| Meal type | `meal_type` | enum (`breakfast`, `lunch`, `dinner`, `snack`) |
| Name | `name` | text |
| Calories | `calories` | kcal |
| Macros | `protein_g`, `carbs_g`, `fat_g` | g |

## Adding a metric

1. Add the enum value with a **new** `wireName`. Never repurpose an existing one.
2. Add a row to this catalog: canonical unit, entry units, validation range,
   Health Connect mapping (or explicitly "none").
3. Add the drift table column or a new table — see `storage-schema.md`.
4. Add the conversion entries to the `Unit` value object.
5. Add a unit test for conversion in both directions, including the boundary values.
6. Update the entry form (see the `health-manual-entry` skill) if it is manually
   enterable.
7. Write a migration and its test if the schema changed.

## Scope warning

This is already a large surface for a personal tracker. **A metric that is not
entered, imported, or displayed is not a metric** — it is dead schema. Before
adding one, ask whether it earns its place on the dashboard. The catalog above is
a ceiling, not a floor to fill.
