# ADR 0006 — Web Backend: Next.js Route Handlers + Neon Postgres & Shared Sync Contract

## Status

Accepted (2026-10-23). Governs the Next.js PWA in `web/` per `docs/web/`.

## Context

`docs/web/README.md` and `docs/web/01-foundations.md` specify that Healthie Web is a standalone installable Next.js + TypeScript PWA in `web/` backed by **Neon Postgres** via Next.js Route Handlers (`@neondatabase/serverless` + Drizzle ORM) and first-party cookie-session auth. Meanwhile, mobile (`CLAUDE.md` / `docs/api-contract.md`) speaks the shared REST sync contract. As noted in `docs/web/risks-milestones.md`, two separate databases cannot converge if mobile and websync to different backends.

## Decision

1. **Neon Postgres is the authoritative cloud Postgres store for the web track**, accessed exclusively on the server via Next.js Route Handlers and Drizzle ORM (`DATABASE_URL` pooled for runtime, `DATABASE_URL_UNPOOLED` direct for migrations).
2. **Unified Sync Wire Contract**: The Next.js Route Handlers implement both the web sync endpoints (`/api/sync/push`, `/api/sync/pull`) and the v1 contract endpoints (`/api/v1/sync/upload`, `/api/v1/sync/changes`, `/api/v1/measurements`) against the same Neon `measurements` and `sync_cursors` tables, using identical `wire_name`s, canonical units, device-generated UUIDv4 IDs, last-write-wins (`client_updated_at`), and **tombstone-wins** semantics.
3. **Dual-layer Per-User Isolation**: Every query in the Route Handlers scopes by authenticated `user_id` at the application layer **and** executes inside a Postgres RLS context (`SET LOCAL app.current_user_id = ...`) on Neon tables.
4. **Shell-only Service Worker Caching**: The PWA service worker precaches the static app shell only and explicitly excludes `/api/*` from Cache Storage so health payloads exist only in IndexedDB on the client.

## Consequences

- Both web (cookie session) and mobile (bearer token or session) can sync against the same Neon database and wire shapes defined in `docs/api-contract.md`.
- Client components are forbidden from importing `@neondatabase/serverless` or `drizzle-orm` (enforced in CI via `npm run check:layering`).
