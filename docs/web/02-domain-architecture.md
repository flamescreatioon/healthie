# Phase 1 — Domain Port + App Architecture

Source specs: `health-domain-model`, `flutter-architecture` (read as specifications, not Dart guides). Authority for wire formats: `docs/api-contract.md`. Backend: Neon via first-party Route Handlers (no Supabase client on web).

## Goal

The same domain vocabulary and layering rules as mobile, expressed in TypeScript, with Next.js routing mirroring the mobile routes.

## Steps

1. Port the domain vocabulary 1:1 — Measurement vs Summary vs Series, Source vs Sync state, local-day rule, three timestamps (`recordedAt` / `createdAt` / `updatedAt`). No renames, no reinterpretation.
2. Port the metric catalog as data: stable `wireName` per metric, canonical storage unit, entry units, validation ranges, per-metric decimal precision. `wireName`s are a permanent contract — never rename an existing one.
3. Implement the TypeScript layering rule mirroring mobile (`components → domain ← data`):
   - `domain/` — pure types, validation, unit conversion, date grouping. No IndexedDB, no fetch, no Neon/Drizzle, no React imports.
   - `data/` — Dexie tables/DAOs, repository implementations, sync API client (typed `fetch` to the Route Handlers). The only layer that knows about IndexedDB or the network.
   - `app/` (routes + Route Handlers) + `components/` — screens, hooks, and the `/api/*` handlers. UI knows domain interfaces only; server handlers own Drizzle/Neon access and session checks. Never import Drizzle/Neon into client components.
4. Mirror mobile routes in the Next.js App Router (`/`, `/track`, `/history`, `/analytics`, `/metric/:type`, auth routes). Record links open the right record; health values never appear in URLs (IDs only).
5. State: TanStack Query for watched data (the equivalent of Drift reactive streams + Riverpod `StreamProvider`); mutations write to IndexedDB first, then enqueue outbox rows, then trigger sync. UI updates from the local store, never by awaiting the network.
6. Add a layering check to CI (an ESLint boundary rule or a small script, mirroring mobile's `tool/check_layering.dart`), including a ban on client-side Neon/Drizzle imports.

## Exit criteria

- [ ] Domain package imports nothing but TS stdlib (no DB, no network, no React).
- [ ] Repository interfaces are platform-blind; UI depends on interfaces, not Dexie/fetch.
- [ ] No Neon/Drizzle import reachable from client components (CI-enforced).
- [ ] All routes resolve by URL, including record deep links with IDs only.
- [ ] App boots with fake repositories (Storybook/test), no browser-storage or network dependency in components.
