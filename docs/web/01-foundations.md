# Phase 0 — Next.js + PWA + Neon Setup

Web stack: **Next.js + TypeScript PWA** in `web/`. Backend: **Neon Postgres** (not Supabase).

## Goal

A clean Next.js App Router PWA scaffold backed by Neon, that the shared contracts (`docs/api-contract.md`, metric catalog, sync protocol) can build on.

## Steps

1. Scaffold `web/` with Next.js (App Router) + TypeScript strict + ESLint. Node LTS; document the pinned Node/Next versions in `web/README.md` and re-check before upgrades.
2. PWA scaffold from day one (not a retrofit): `manifest.webmanifest` (name, icons incl. maskable, `display: standalone`, `theme_color` matching the design tokens), service worker via Serwist/`next-pwa` (or equivalent), offline app-shell route, versioned update prompt. Installability is a launch blocker.
3. Configure env: Neon pooled `DATABASE_URL` for server runtime + direct (non-pooled) URL for Drizzle migrations. Never commit secrets; only `NEXT_PUBLIC_*` non-secrets reach the browser. The database connection string never ships to the client — all DB access goes through Route Handlers.
4. Install the web data stack up front:
   - `@neondatabase/serverless` + `drizzle-orm` (+ `drizzle-kit` for migrations) for Neon Postgres access from Route Handlers.
   - First-party auth backed by Neon (Better Auth or Auth.js-style with Drizzle adapter): cookie sessions, server-side session checks. No Supabase Auth on web.
   - Dexie.js (IndexedDB wrapper) for the offline-first local store + outbox.
   - TanStack Query for server-state caching/sync status; a small client store (Zustand or context) for UI state only.
   - `recharts` for charts (Phase 5), `react-hook-form` + `zod` for forms (Phase 4) — add when those phases start, not before.
5. Spike the three unknowns before any UI work:
   - IndexedDB schema mirroring the Drift tables, including the outbox transaction story and Dexie versioned migrations.
   - Neon round-trip from a Route Handler (Drizzle query + migration run) against a Neon branch, including pooled vs direct connection behaviour.
   - Cookie-session auth sign in/out against Neon from the browser, with middleware refresh and server-component session reads.
6. Done-gate for every phase: `tsc --noEmit` clean, ESLint clean, tests green, `next build` succeeds, Lighthouse PWA baseline recorded.

## Backend divergence (Neon, not Supabase)

- Mobile per `CLAUDE.md` targets Supabase. Web targets Neon. See `README.md` — Neon must become the shared Postgres or a blocker ADR is required before Phase 3; two databases cannot converge.
- Supabase-specific pieces do **not** carry over: no PostgREST, no GoTrue, no `auth.uid()` helper, no `supabase-js`/`ssr` packages on web. Their *rules* carry over (per-user isolation, session handling, tombstone sync) re-implemented on Neon — see Phase 3.
- Neon specifics to confirm in this phase: region/branch strategy, pooled connection limits for serverless Route Handlers, migration workflow (`drizzle-kit`), and the DPA/residency facts the privacy policy will need (Phase 7).

## Service-worker data rule (set now, enforced in Phase 7)

- The service worker caches the static app shell only. Health-record API payloads are **never** put in Cache Storage — offline reads come from IndexedDB, not the HTTP cache.

## Divergences from mobile (by design)

- No Dart/Flutter toolchain on web: no `build_runner`, no `flutter analyze`, no Drift, no `path_provider`, no `minSdk`/Gradle/manifest work.
- No `health` package, no Health Connect, no HealthKit.
- Contracts are shared; code is not. `wireName`s, validation ranges, and the sync protocol must stay identical — see Phase 1.

## Exit criteria

- [ ] `npm ci` resolves with no conflicts; versions pinned in `web/README.md`.
- [ ] `tsc --noEmit` clean, ESLint clean.
- [ ] Unit test runner green on an empty suite.
- [ ] `next dev` and `next build` succeed; PWA manifest + service worker register in dev.
- [ ] Auth spike signs in/out against Neon from the browser with cookie sessions.
- [ ] Drizzle migration applies cleanly to a Neon branch.
- [ ] IndexedDB spike writes + reads + survives reload.
