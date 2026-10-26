# Phase 5 — Validation (FormRequests mirror the domain model)

- `MeasurementRequest`: `metric_type` in catalog wire names; canonical `unit`
  required; range checks per metric (weight 20–400 kg, HR 20–250 bpm,
  sys 50–260 / dia 30–160 mmHg, temp 30–45 °C, SpO₂ 50–100, sleep 0–24 h,
  water 0–20 L/day, steps 0–200 000/day); reject out-of-range with the
  `{"error","message","field"}` shape — never silently clamp.
- Composite metrics: BP requires value+secondary (+tertiary pulse optional);
  unknown `context` keys rejected.
- `recorded_at` ISO-8601 UTC; `local_day` `Y-m-d` — accept as sent (device
  froze grouping at record time, incl. travel/DST). Validate format only.
- Sync batch: `entity_type` in allowlist; `entity_id` UUID; `operation` enum;
  `client_updated_at` timestamp; payload validated as its resource.
- Permanent failures (400/403/422) returned per-row so the client can
  **quarantine** the op instead of retrying forever and wedging its queue.

Next: [Client sync contract](./06-client-sync-contract.md).
