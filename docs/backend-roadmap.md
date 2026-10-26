# Healthie Backend — Implementation Roadmap & Plan (Laravel)

> Greenfield backend. No backend code exists yet.
> Backend choice (locked by user): **Laravel REST API + PostgreSQL + Sanctum**.
> This **supersedes ADR-0004** (which chose Supabase) — see
> `docs/adr/0005-backend-laravel.md` for the reversal record.
> Authoritative endpoint contract: `docs/api-contract.md` (already written
> for Laravel Sanctum-style bearer tokens under `/api/v1`).
> Local model: `docs/architecture.md`. Domain rules: `health-domain-model` skill.
> Privacy obligations: `health-privacy-compliance` skill.
> The `health-cloud-sync` skill still describes the offline-first *pattern*
> (outbox, cursor, tombstone-wins) correctly, but every Supabase-specific
> detail in it (GoTrue, PostgREST, RLS, `sync_push`/`sync_pull` RPCs,
> `supabase_flutter`) does **not** apply — this document replaces those
> with the Laravel equivalents.

**Core principle (unchanged):** Local Drift DB is the source of truth the UI
reads. Laravel is a replica brought up to date via an offline-first outbox.
No repository method ever awaits the network.

```
UI → Repository (domain interface)
       ↓
     Drift (local DB) ← source of truth
       ↓ outbox table
     SyncService → Laravel REST (/api/v1, Sanctum bearer)
       ↓
     PostgreSQL → authorized per user (Policies, never trust client)
```

---

## 0. Prerequisites & Decisions (read first)

Read before writing anything:

- `docs/api-contract.md` — the REST contract to implement (auth, measurements,
  sync/upload, profile/goals, reminders, exports, error shape, rate limiting).
- `docs/architecture.md` — local-first, device-assigned IDs, idempotency,
  one-operation-per-entity outbox, client-driven conflict resolution.
- `health-domain-model` skill — `wireName` stability, `local_day` rule,
  canonical units, validation ranges, soft-delete rule.
- `health-privacy-compliance` skill — deletion, export, policy, Play declaration.
- `flutter-architecture` skill — when wiring the Dart `SyncService` side.

Locked decisions:

| Decision | Value |
|---|---|
| Stack | Laravel (PHP 8.3+, Laravel 12) + PostgreSQL, Sanctum bearer tokens |
| Base path | `/api/v1`, JSON, ISO-8601 UTC timestamps |
| Tables v1 | `measurements`, `workouts`, `sleep_sessions`, `meals`, `profiles`, `goals`, `reminders` |
| Identity | `id` = device-generated UUIDv4 string (offline create); server never assigns IDs for client-created rows |
| Ownership | `user_id` FK → `users.id`, `cascadeOnDelete`; **every** query scoped to `auth()->id()` via Policy + global scope |
| Conflict | Client-driven: `updated_at` (device `client_updated_at`) wins; **tombstone wins over edit**; deterministic server-wins tiebreak |
| Pull cursor | Monotonic server watermark (`server_updated_at` / `server_timestamp`), stored in local DB in same txn as applied rows |
| `local_day` | `DATE`, computed on-device from user timezone, sent as-is. Server validates format, never recomputes |
| `wireName` / `metric_type` | Permanent contract. Renaming breaks sync for all existing rows |
| Sync | **Opt-in.** App works fully local without it |
| Units | Store canonical only (kg, cm, mmHg, °C). Convert at Flutter form/display boundary, once |

---

## 1. Laravel Project Bootstrap

1. `composer create-project laravel/laravel healthie-backend`, PHP 8.3+,
   PostgreSQL driver (`pdo_pgsql`), Redis optional (queues/cache).
2. `composer require laravel/sanctum`, `php artisan vendor:publish`, Sanctum
   middleware on `api` group. Token = opaque bearer, stored hashed.
3. Config: `APP_TIMEZONE=UTC`, API timezone UTC everywhere; CORS locked to
   app origins; `SESSION_DRIVER` irrelevant for token API; queue driver set
   (database/redis) for export + pruning jobs.
4. Environments: local → staging → prod. `.env` per env, secrets in vault/CI
   only. Never commit `.env`. TLS everywhere; reject non-HTTPS in release.
5. Tooling: Laravel Pint (format), PHPStan/Larastan (static analysis),
   Pest or PHPUnit feature tests, `php artisan test` green before merge.
6. Rate limiting (`throttle:api` + stricter `throttle:auth` on
   register/login and `throttle:sync` on `sync/upload`) — mobile clients retry
   aggressively on flaky connections.

**Done when:** `php artisan migrate:fresh --seed` + `php artisan test` pass on
a clean checkout; `/api/v1/health` (or equivalent) returns 200 over HTTPS.

---

## 2. Schema Migrations (PostgreSQL)

One migration file each. Never edit a shipped migration — add a new one.

- `users` — Laravel default + Sanctum `personal_access_tokens`. Add
  `display_name`, `unit_preferences` (JSON), `deleted_at` if soft-deleting users.
- `measurements` — `id uuid PK` (client-generated), `user_id FK cascade`,
  `metric_type text`, `value double`, `unit text`, `secondary_value/secondary_unit`,
  `tertiary_value/tertiary_unit` (BP composite per ADR-0001),
  `recorded_at timestamptz`, `local_day date`, `source enum(manual,health_connect,imported,derived)`,
  `context_json jsonb NULL`, `client_updated_at timestamptz` (device clock, LWW compare),
  `server_updated_at timestamptz` (server clock, pull cursor),
  `created_at/updated_at`, `deleted_at` (SoftDeletes = tombstone).
  Indexes: `(user_id, local_day)`, `(user_id, metric_type, recorded_at DESC)`,
  `(user_id, server_updated_at)`.
- `workouts`, `sleep_sessions`, `meals` — same ownership/clock/tombstone
  columns, own domain fields (mirror the Supabase reference DDL field lists
  in `health-cloud-sync/references/backend-schema.md`, ported to Laravel
  migrations).
- `profiles`, `goals`, `reminders` — per `docs/api-contract.md` §2
  (profile, health goals with metric type + target + unit + optional date,
  reminders with kind + metric + local time + enabled).
- Review rules: durations integer seconds/minutes; measurements double;
  counts integer; `unit` explicit on every row; `local_day` never recomputed
  server-side; `metric_type` wire names match
  `health-domain-model/references/metric-catalog.md`.

**Done when:** `migrate:fresh` builds all tables + indexes; wire names match
the metric catalog.

---

## 3. Auth (Sanctum) + Authorization (replaces RLS)

Auth (`POST /api/v1/auth/register|login|logout`):

1. `RegisterRequest`/`LoginRequest` validation; `Hash::make` passwords;
   `createToken('mobile', ['sync'])` on register/login; `currentAccessToken()->delete()`
   on logout; revoke all on password change.
2. 401 = dead/rotated token → client drops token, routes to sign-in. No silent
   retry loop, no second refresh mechanism (Sanctum tokens don't refresh).
3. Rate-limit auth endpoints per IP + per email/device.
4. Never log tokens, passwords, or `Authorization` headers — not in Laravel
   logs, Telescope, Horizon, or error reporters. Redact before it leaves
   the server.

Authorization — server enforces ownership on **every** request (replaces
Supabase RLS):

1. Global scope / base query: everything private is `->where('user_id', auth()->id())`.
2. `MeasurementPolicy` (etc.) per model: `view/update/delete` require
   `$model->user_id === $user->id`. Register in `AuthServiceProvider`.
3. Route-model binding scoped: `Route::apiResource(...)->scoped()` or explicit
   `where user_id` lookup — a raw `findOrFail($id)` without ownership check
   is a leak.
4. `GET /api/v1/measurements/{id}` for another user's id → 404 (not 403, to
   avoid id-oracle). Same for PUT/DELETE.

Verify **before any sync client code** (feature tests with two users, `actingAs`):

1. User B `GET /measurements` sees 0 of A's rows; `GET /measurements/{a-id}` → 404.
2. B `PUT/DELETE {a-id}` → 404; A unaffected.
3. Unauthenticated → 401 on every private route.
4. Expired/revoked token → 401; client signs out cleanly.

---

## 4. Sync Endpoints (replaces `sync_push`/`sync_pull` RPCs)

Implement `docs/api-contract.md` §2 "Sync" plus resource CRUD. Two endpoints
form the replication protocol:

- `POST /api/v1/sync/upload` — client sends pending outbox ops as a batch
  `[{entity_type, entity_id, operation(upsert|delete), payload, client_updated_at}]`.
  Server processes **in order, idempotently** (keyed by `(user_id, entity_id)`),
  applies LWW + tombstone-wins, and returns per-row
  `{entity_id, status: accepted|conflict|rejected, server_row?}` plus
  `server_timestamp` watermark.
- `GET /api/v1/sync/changes?since={server_timestamp}` — ordered
  (`server_updated_at ASC`) changelog across entity types since cursor:
  `[{entity_type, entity_id, operation, payload, server_updated_at}]`.
  Client applies in one local txn and advances its cursor in the **same txn**.
- Optional `POST /api/v1/sync/ack` (per api-contract `sync/sync` confirmation)
  so the server can prune its change log / outbox.

Server push semantics (per row):

- No row for `(user_id, entity_id)` → insert.
- Existing `deleted_at` set + incoming edit → `rejected`, return tombstone.
- Existing, no tombstone → apply iff incoming `client_updated_at` >
  stored, else `conflict` + return server row (deterministic server-wins tiebreak
  on equality).
- `delete` op always applies (SoftDeletes `delete()`), idempotent no-op if
  already deleted.

Also ship the resource CRUD the contract requires (measurements list with
`metric_type` / `recorded_at.gte|lt` / `is_synced` filters + pagination,
single read/update/soft-delete; profile/goals; reminders) with identical
ownership + validation.

---

## 5. Validation (FormRequests mirror the domain model)

- `MeasurementRequest`: `metric_type` in catalog wire names; canonical `unit`
  required; range checks per metric (weight 20–400 kg, HR 20–250 bpm,
  sys 50–260 / dia 30–160 mmHg, temp 30–45 °C, SpO₂ 50–100, sleep 0–24 h,
  water 0–20 L/day, steps 0–200 000/day); reject out-of-range with the
  `{"error","message","field"}` shape — never silently clamp.
- Composite metrics: BP requires value+secondary (+tertiary pulse optional);
  unknown `context` keys rejected.
- `recorded_at` ISO-8601 UTC; `local_day` `Y-m-d`, must match nothing
  server-side — accept as sent (device froze grouping at record time, incl. travel/DST).
- Sync batch: `entity_type` in allowlist; `entity_id` UUID; `operation` enum;
  `client_updated_at` timestamp; payload validated as the corresponding resource.
- Permanent failures (400/403/422) returned per-row so the client can
  **quarantine** the op instead of retrying forever and wedging its queue.

---

## 6. Client Sync Contract (Flutter side, HTTP not Supabase)

`SyncService` speaks `https://<host>/api/v1` with Sanctum bearer
(`Authorization: Bearer <token>` from secure storage), not `supabase_flutter`:

1. **Outbox (Drift, unchanged):** data write + outbox enqueue in **one txn**.
2. **Push:** atomic claim (`UPDATE … WHERE is_processing=0 … RETURNING *`),
   compact to latest op per entity (delete wins), `POST sync/upload`, apply
   per-row results (`accepted` → dequeue; `conflict` → overwrite local with
   `server_row`; `rejected` → re-apply deletion + non-blocking notice).
3. **Pull:** cursor from DB (not prefs) → `GET sync/changes?since=` → apply in
   one txn → advance cursor to returned `server_timestamp` in **same txn**.
4. **Triggers:** after write (debounce 3–5 s) → connectivity restored
   (interface ≠ internet — handle captive portals) → foreground if stale →
   `workmanager` periodic (own isolate, own HTTP client + DB) → manual Sync now.
5. **Retry:** exp backoff + jitter (2 s…32 s, cap 5 min), bounded attempts,
   durable outbox (never discard); retryable = network/5xx/429, quarantine =
   400/403/422. Never block a visible write; background failure = log + tiny
   "not synced" indicator max; never upload raw Health Connect payloads.

---

## 7. Deletion, Export, Retention

1. `DELETE /api/v1/account` (auth + password confirm): `forceDelete` user;
   FK `cascadeOnDelete` removes health rows. Feature-test the cascade —
   a leftover row is a privacy defect. Client then clears local DB + signs out.
2. `GET /api/v1/exports/measurements?from&to&metric_type` → queued export job,
   returns export reference; download via signed URL; payload = same shape as
   offline Drift export (JSON + CSV + schema version).
3. Inactive-account retention period defined, implemented (scheduled command),
   stated in privacy policy; backups expire on the same schedule.
4. Document uninstall story: what happens to the server copy.

---

## 8. Privacy, Policy & Play Gates

From `health-privacy-compliance` — backend can't ship without these:

- Privacy policy live URL: what is collected; where it goes (device default;
  **this Laravel backend named as processor with region** on sync opt-in);
  Health Connect read-only; account deletion; export; TLS + at-rest encryption
  (managed Postgres + encrypted disks); no sale / no ads; contact; effective
  date + changelog.
- Data handling audit: no health values in Laravel logs, Telescope, Horizon,
  crash breadcrumbs, analytics, URLs (record IDs, never values; generic screen
  names like `metrics_detail`), or clipboard; `FLAG_SECURE` considered.
- Play: health apps declaration + per-permission justification matching actual
  `READ`-only manifests; data safety form accurate; in-app rationale screen;
  medical disclaimer where readings appear.
- Sync opt-in explicit, separate from account creation; opting out never
  deletes local data.

---

## 9. Testing & Done Criteria

Backend (Pest/PHPUnit feature tests, two-user matrix) + client tests
(`flutter-testing` skill) written alongside, not after.

- [ ] Offline write appears instantly, reaches server when online
- [ ] Second device sees record after pull (`sync/changes`)
- [ ] Authz: second user sees/modifies nothing (404 matrix, §3)
- [ ] Concurrent edit converges, no duplication (deterministic tiebreak)
- [ ] Delete propagates; tombstone wins over concurrent edit
- [ ] Batch replay is idempotent (no duplicates)
- [ ] No tokens / passwords / health values in server logs
- [ ] Account deletion clears server data (verified in DB)
- [ ] `php artisan test` green; `flutter analyze` clean, `flutter test` green

---

## Build Order

1. Bootstrap (§1) + users/Sanctum + rate limits
2. Migrations (§2: measurements first, then workouts/sleep/meals, then profiles/goals/reminders)
3. Policies + 404-matrix tests (§3)
4. Measurements CRUD + validation (§4–§5)
5. `sync/upload` + `sync/changes` (+ `ack`) + conflict matrix tests (§4)
6. Account delete + exports + retention (§7)
7. Flutter `SyncService` HTTP rewrite + triggers/backoff (§6) → airplane-mode + second-device tests
8. Policy + Play artefacts (§8) → done checklist (§9)

**Backfill rule for later:** nullable column = safe/lazy; rename =
expand/contract (add → dual-write → backfill → switch reads → drop); never
change a `wireName`; never mutate a shipped migration.
