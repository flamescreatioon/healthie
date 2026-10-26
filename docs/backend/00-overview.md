# Healthie Backend — Overview (Laravel)

> Greenfield backend. No backend code exists yet.
> Backend choice (locked by user): **Laravel REST API + PostgreSQL + Sanctum**,
> superseding ADR-0004 (Supabase). Record: `docs/adr/0005-backend-laravel.md`.
> Authoritative endpoint contract: `docs/api-contract.md`.
> The `health-cloud-sync` skill's offline-first *pattern* still applies; its
> Supabase specifics (GoTrue, PostgREST, RLS, RPCs) do not.

**Core principle:** Local Drift DB is the source of truth the UI reads.
Laravel is a replica brought up to date via an offline-first outbox.
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

## Locked decisions

| Decision | Value |
|---|---|
| Stack | Laravel (PHP 8.3+, Laravel 12) + PostgreSQL, Sanctum bearer tokens |
| Base path | `/api/v1`, JSON, ISO-8601 UTC |
| Tables v1 | `measurements`, `workouts`, `sleep_sessions`, `meals`, `profiles`, `goals`, `reminders` |
| Identity | `id` = device UUIDv4 string; server never assigns IDs for client rows |
| Ownership | `user_id` FK cascade; every query scoped to `auth()->id()` |
| Conflict | Client-driven LWW on `client_updated_at`; **tombstone wins**; server-wins tiebreak |
| Pull cursor | Server `server_updated_at` watermark, stored in local DB same-txn |
| `local_day` | `DATE` from device, never recomputed server-side |
| `wireName` | Permanent contract |
| Sync | **Opt-in**; app fully local without it |
| Units | Canonical only (kg, cm, mmHg, °C) |

## Skills/docs to read before each phase

- `docs/api-contract.md` + `docs/architecture.md`
- `health-domain-model` — wire names, `local_day`, units, ranges, soft-delete
- `health-privacy-compliance` — deletion, export, policy, Play
- `flutter-architecture` — Dart `SyncService` wiring

## Build order

1. [Bootstrap](./01-bootstrap.md) — Laravel + Sanctum + rate limits
2. [Schema](./02-schema.md) — migrations for all tables
3. [Auth & authorization](./03-authorization-verification.md) — Sanctum + Policies + 404 matrix
4. [Sync endpoints](./04-sync-endpoints.md) — upload/changes/ack + CRUD
5. [Validation](./05-validation.md) — FormRequests mirror domain ranges
6. [Client sync contract](./06-client-sync-contract.md) — HTTP SyncService
7. [Deletion, export, retention](./07-deletion-export-retention.md)
8. [Testing & done criteria](./08-testing-done-criteria.md)

Backfill rule: nullable column = safe/lazy; rename = expand/contract
(add → dual-write → backfill → switch reads → drop); never change a
`wireName`; never mutate a shipped migration.
