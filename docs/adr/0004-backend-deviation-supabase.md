# ADR 0004 — Backend deviation: Supabase vs Laravel

## Status

Accepted

## Context

The master development prompt recommends a **Laravel REST API with
PostgreSQL**. The repository's own `health-cloud-sync` skill and
`flutter-project-setup` skill specify **Supabase** (auth + Postgres) as the
backend, and the verified dependency set includes `supabase_flutter`.

## Decision

**Use Laravel REST API + PostgreSQL on Neon.** Laravel (Sanctum bearer auth)
is the backend; Postgres is hosted on Neon (shared with the Next.js web app).

### Rationale

- The repository's skills are the authoritative source of truth for this
  codebase's toolchain and platform behaviour; they name `supabase_flutter`
  and Drift, not Laravel.
- The local-first sync layer (`lib/core/sync/sync_outbox_dao.dart`,
  `SyncOutbox`) is backend-agnostic: device-assigned UUIDs, idempotent
  operations keyed by entity id, one operation per entity, tombstone-wins.
  It can drain to Supabase without changing the client data model.
- The [API contract](api-contract.md) is written against the local data model
  and can be implemented against either backend; Supabase is simply the one
  this project's skills pin.

## Consequences

- Laravel backend lives at `backend/api/`; Neon Postgres is shared with the
  web app (`web/.env.local`).
- `supabase_flutter` is no longer the planned backend client; the mobile
  sync layer talks to Laravel via `BackendClient` (`lib/core/sync/backend_client.dart`).
