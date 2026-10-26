# Phase 3 — Auth + Sync API (Next.js + Neon)

Source spec: `health-cloud-sync` **protocol** (its Supabase product specifics are replaced — see below). Backend: Neon Postgres via Drizzle, behind first-party Route Handlers. `docs/api-contract.md` is the wire authority both clients implement.

## Goal

Same sync guarantees as mobile (offline-first, outbox push, cursor pull, tombstone-wins, per-user isolation) — implemented on Neon with cookie-session auth, no Supabase.

## What replaces Supabase here

| Mobile / skill assumes | Web (Neon) does instead |
|---|---|
| PostgREST | Typed Next.js Route Handlers (`/api/sync/push`, `/api/sync/pull`, record CRUD) with zod-validated bodies |
| GoTrue + `supabase-js`/`ssr` | Cookie-session auth backed by Neon tables (Better Auth / Auth.js-style + Drizzle adapter); session checked server-side in middleware + each handler |
| `auth.uid()` RLS helper | `user_id` scoping in every query **plus** Postgres RLS on the Neon tables (e.g. session-variable-based policy), so a missing app-layer check still cannot leak rows |
| `service_role` key discipline | `DATABASE_URL` lives server-side only; the browser never sees it |
| `workmanager` background sync | Web triggers + service-worker Background Sync (below) |

## Steps

1. Neon schema via Drizzle + `drizzle-kit` migrations: same logical tables as the mobile backend spec (measurements with `wire_name`, canonical value + unit, `recorded_at`/`created_at`/`updated_at`, `deleted_at`, `user_id`; sync cursor per user/device). Never mutate a shipped migration — add a new one. Nullable-column additions backfill lazily; renames use expand/contract.
2. Auth: sign-up/sign-in/sign-out routes, session cookie (HttpOnly, Secure, SameSite), middleware refresh, signed-in vs signed-out routing in one place. Session handling: one refresh + one retry on 401, then sign out with a plain message. Never log tokens, sessions, or auth headers. Sign-out keeps/locks local IndexedDB data per policy; clearing local data requires explicit user consent.
3. Per-user isolation enforced twice: app-layer `user_id` checks in every handler **and** Postgres RLS. Test second-user isolation against the real Neon branch (user B cannot read/write user A's rows even with crafted request bodies).
4. Same push / pull / cursor / conflict rules as the skill's protocol: outbox push with `client_updated_at`; pull with `updated_at > cursor` where the cursor is persisted alongside the applied rows; last-write-wins with **tombstone-wins** over concurrent edits. Server applies pushes transactionally and returns the authoritative cursor.
5. Web sync triggers: post-write debounce, `online` event, tab focus / `visibilitychange`, in-tab interval, plus service-worker **Background Sync** (`sync` event draining the outbox) where the browser supports it. Closed-tab sync without Background Sync support is best-effort — document the matrix. Failures retry with backoff and stay silent in the UI beyond a small "not synced" indicator.
6. Sync health records only. Never sync anything web-specific that mobile would not understand, and never raw payloads that were never turned into records.

## Exit criteria

- [ ] Offline write appears instantly, reaches Neon on reconnect (foreground and, where supported, via Background Sync).
- [ ] Second browser (or mobile, once it speaks the same contract) sees the record after pull.
- [ ] Two-client edit converges with no duplication.
- [ ] Delete on one client removes it on the other; tombstone wins over concurrent edit.
- [ ] Second-user isolation verified at both the API layer and Postgres RLS.
- [ ] Tokens / connection strings never appear in logs or client bundles.
- [ ] Account deletion removes all Neon rows (cascade verified).
