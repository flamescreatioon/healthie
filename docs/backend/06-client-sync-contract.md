# Phase 6 — Client Sync Contract (Flutter side, HTTP not Supabase)

`SyncService` speaks `https://<host>/api/v1` with Sanctum bearer
(`Authorization: Bearer <token>` from secure storage), not `supabase_flutter`.

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

Next: [Deletion, export, retention](./07-deletion-export-retention.md).
