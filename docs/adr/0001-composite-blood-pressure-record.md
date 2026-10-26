# ADR 0001 — One blood-pressure row per reading, systolic + diastolic + pulse

## Status

Accepted

## Context

A blood-pressure reading is structurally a pair (systolic + diastolic) plus an
optional companion pulse. Two schema shapes were considered:

1. **One row per metric value** — systolic row, diastolic row, pulse row, all
   sharing a session id. This follows the PRD's metric catalog literally
   (`blood_pressure_systolic`, `blood_pressure_diastolic`) and keeps every
   row a plain scalar.
2. **One row per reading** — systolic as `value`, diastolic as
   `secondary_value`, pulse as `tertiary_value`. This is the PRD's suggested
   escape hatch ("use `value` for systolic and `secondary_value` for
   diastolic, or use a more explicit typed schema").

## Decision

**Option 2.** One row per reading.

### Rationale

- **One source of truth.** A single insert per reading, one transaction, one
  outbox operation. Two rows per reading doubles the failure surface (a
  crash between the two inserts leaves systolic without diastolic).
- **Trivial queries.** "Everything recorded on this day" is one scan over
  one table, with no self-join required to pair systolic with diastolic.
- **Simple sync.** One entity id per reading, one outbox row per reading.

### Trade-off

- The row is "wide" with nullable columns for metric-specific fields
  (posture, arm, circumstances live in `context_json`). This is acceptable
  because Healthie's metric set is small and stable, and the alternative —
  one table per metric — fragments queries the dashboard runs constantly.

## Consequences

- The PRD's separate wire names `blood_pressure_systolic` and
  `blood_pressure_diastolic` are kept as *component* names in export/API
  payloads; the persisted metric type is `blood_pressure`.
- Classification is evaluated on one row (`value` / `secondary_value`).

## Related

- ADR 0004: backend deviation (Supabase vs Laravel).
