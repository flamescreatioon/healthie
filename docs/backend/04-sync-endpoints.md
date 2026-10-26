# Phase 4 — Sync Endpoints (replaces `sync_push`/`sync_pull` RPCs)

Implements `docs/api-contract.md` §2 "Sync" plus resource CRUD.

## Replication protocol

- `POST /api/v1/sync/upload` — client sends pending outbox ops as a batch:
  `[{entity_type, entity_id, operation(upsert|delete), payload, client_updated_at}]`.
  Server processes **in order, idempotently** (keyed by `(user_id, entity_id)`),
  applies LWW + tombstone-wins, returns per-row
  `{entity_id, status: accepted|conflict|rejected, server_row?}` plus a
  `server_timestamp` watermark.
- `GET /api/v1/sync/changes?since={server_timestamp}` — ordered
  (`server_updated_at ASC`) changelog across entity types since cursor:
  `[{entity_type, entity_id, operation, payload, server_updated_at}]`.
  Client applies in one local txn, advances cursor in the **same txn**.
- Optional `POST /api/v1/sync/ack` (api-contract `sync/sync` confirmation)
  so the server can prune its change log.

## Server push semantics (per row)

- No row for `(user_id, entity_id)` → insert.
- Existing `deleted_at` set + incoming edit → `rejected`, return tombstone.
- Existing, no tombstone → apply iff incoming `client_updated_at` > stored,
  else `conflict` + return server row (deterministic server-wins on equality).
- `delete` op always applies (SoftDeletes `delete()`), idempotent no-op if
  already deleted.

## Resource CRUD (same ownership + validation)

Measurements list with `metric_type` / `recorded_at.gte|lt` / `is_synced`
filters + pagination; single read/update/soft-delete; profile/goals; reminders.

Next: [Validation](./05-validation.md).
