# API contract

This document specifies the REST contract a future backend must implement for
Healthie's offline-first sync. It is written against the **local** data model,
so everything here can be verified against the Drift schema before a server
exists.

---

## 1. Principles

- **Local-first.** Every write is committed locally before it is ever offered
  to the network. The sync path is a replication target, never a prerequisite
  for showing the user their own data.
- **Device-assigned IDs.** IDs are strings generated on the device
  (`uuid4`). The server never assigns the ID authority for locally created
  records, because the phone may be offline for days.
- **Idempotency.** Operations are keyed by entity id so that retries are
  safe and a retry of an upload never creates a duplicate.
- **One operation per entity.** The local outbox holds at most one pending
  operation per entity id; a `delete` replaces a pending `upsert`, so a
  tombstone always wins over an upload that has not gone out yet.
- **Client-driven conflict resolution.** On conflict, `updated_at` wins
  (tombstone-wins for deletes); the server does not invent its own resolution
  policy.

---

## 2. Endpoints

All endpoints are under `/api/v1`. Every private endpoint requires
authentication (Laravel Sanctum-style bearer token) and enforces object-level
authorization — the server never trusts the client to only touch its own
records.

### Authentication

| Endpoint | Purpose |
|---|---|
| `POST /api/v1/auth/register` | Create an account |
| `POST /api/v1/auth/login` | Obtain an access token |
| `POST /api/v1/auth/logout` | Revoke the current token |

### Measurements

| Endpoint | Purpose |
|---|---|
| `GET /api/v1/measurements` | List measurements (filters: `metric_type`, `recorded_at.gte`, `recorded_at.lt`, `is_synced`; pagination) |
| `POST /api/v1/measurements` | Upsert one measurement (idempotent by `id`) |
| `GET /api/v1/measurements/{id}` | Read one measurement |
| `PUT /api/v1/measurements/{id}` | Update one measurement |
| `DELETE /api/v1/measurements/{id}` | Soft-delete one measurement |

A `POST` body is one `Measurement` JSON object (see below). An `id` that
already exists replaces the record; an id that does not exist creates it.
Because retries are safe, re-sending an upload is equivalent to the first
send.

### Sync

| Endpoint | Purpose |
|---|---|
| `POST /api/v1/sync/upload` | Upload pending operations |

The client sends its pending outbox operations as a batch. The server
processes them in order, applies idempotently (by entity id + operation), and
returns:

- which ids were accepted,
- which failed and why,
- a list of server-side changes since the client's last sync token
  (`server_timestamp`, entity, operation, payload) for the client to apply
  locally.

The client replies with a `sync/sync` confirmation so the server can prune
its outbox.

### Profile

| Endpoint | Purpose |
|---|---|
| `GET /api/v1/profile` | Read the profile |
| `PUT /api/v1/profile` | Update the profile |
| `GET /api/v1/profile/goals` | List goals |
| `PUT /api/v1/profile/goals/{id}` | Upsert one goal |
| `DELETE /api/v1/profile/goals/{id}` | Delete one goal |

### Health goals

Same shape as the profile goals endpoints above; a goal carries a metric
type, a target value and unit, and an optional target date.

### Reminders

| Endpoint | Purpose |
|---|---|
| `GET /api/v1/reminders` | List reminders |
| `POST /api/v1/reminders` | Upsert one reminder |

Reminders are notification schedules (kind, metric type, local time of day,
enabled). Local delivery is the client's responsibility.

### Export

| Endpoint | Purpose |
|---|---|
| `GET /api/v1/exports/measurements` | Generate a measurement export |

Accepts a date range and measurement type; returns an export reference.
Download is a separate concern (client storage or a signed URL).

---

## 3. Wire shapes

All timestamps are ISO-8601 UTC strings.

### Measurement

```json
{
  "id": "string (device uuid4)",
  "metric_type": "blood_pressure | weight | heart_rate | spo2 | body_temperature | blood_glucose",
  "value": 118,
  "unit": "mmHg",
  "secondary_value": 76,
  "secondary_unit": "mmHg",
  "tertiary_value": 72,
  "tertiary_unit": "bpm",
  "recorded_at": "2026-03-10T08:15:00Z",
  "local_day": "2026-03-10",
  "created_at": "2026-03-10T08:15:00Z",
  "updated_at": "2026-03-10T08:15:00Z",
  "source": "manual",
  "is_synced": false,
  "deleted_at": null,
  "context": {
    "posture": "sitting",
    "arm": "left",
    "circumstances": ["resting"],
    "notes": "...",
    "device": "OMRON connect"
  }
}
```

- `secondary_value` / `tertiary_value` are optional per metric type.
- `context` is optional but validated when present (known keys only).

### Error shape

```json
{
  "error": "validation_failed",
  "message": "Enter a systolic value between 50 and 260 mmHg",
  "field": "value"
}
```

---

## 4. Authorization

Every private endpoint checks:

1. The bearer token is valid and not revoked.
2. The requested entity belongs to the authenticated user.

There is no concept of "the app enforces ownership" — the server enforces it
on every request, for every object.

---

## 5. Rate limiting

Authentication endpoints and the sync endpoint are rate-limited per client,
because a mobile client can retry aggressively on a flaky connection.
