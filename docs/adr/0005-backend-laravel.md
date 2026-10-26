# ADR 0005 — Backend: Laravel REST API + PostgreSQL

## Status

Accepted. Supersedes ADR-0004 (Supabase).

## Context

ADR-0004 chose Supabase (per the repo's `health-cloud-sync` skill) over the
master prompt's Laravel recommendation. The user has now directed that the
backend is **Laravel, not Supabase/Dart-side BaaS**, pointing at the existing
`docs/api-contract.md`, which was already written for a Laravel Sanctum-style
`/api/v1` REST API.

## Decision

Build the backend as a **Laravel REST API + PostgreSQL + Sanctum bearer tokens**
implementing `docs/api-contract.md`. Plan: `docs/backend-roadmap.md` +
`docs/backend/00-overview.md` … `08-testing-done-criteria.md`.

## Rationale

- Explicit user direction; `api-contract.md` already specifies the Laravel shape.
- Team/PHP deploy story preferred over BaaS; ownership enforced via Policies
  instead of RLS.
- Offline-first pattern (outbox, `server_updated_at` cursor, LWW +
  tombstone-wins) is backend-agnostic and ports 1:1 to `sync/upload` +
  `sync/changes`.

## Consequences

- ADR-0004 retained for history; its Supabase choice no longer applies.
- `health-cloud-sync` skill's Supabase specifics (GoTrue, PostgREST, RLS,
  `sync_push`/`sync_pull` RPCs, `supabase_flutter`) do not apply; its sync
  *pattern* (outbox, cursor, tombstone-wins) still does.
- `docs/architecture.md` (device UUIDs, idempotency, one-op-per-entity,
  client-driven conflicts) is unchanged and now binds the Laravel endpoints.
