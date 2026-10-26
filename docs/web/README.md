# Healthie Web — Plan & Roadmap

Next.js + TypeScript PWA mirroring the Flutter mobile UI design. Backend: **Neon Postgres** (not Supabase).

> Plan only — no implementation code. Source: roadmap discussion 2026-10-23, revised to Next.js + Neon + PWA 2026-10-23.

## Decision

**Build web as a standalone installable Next.js PWA in `web/`, not Flutter Web.**

- The Flutter mobile app stays as specified in `CLAUDE.md`.
- The Next.js app reimplements the same screens, components, and flows from the same contracts: metric catalog, `wireName`s, validation ranges, local-day rule, sync protocol, per-user isolation, and design tokens.
- Code is not shared between Dart and TypeScript — the **contracts are shared**. `docs/api-contract.md` is the authority both clients code against.
- Web ships **manual entry only**, same posture as iOS. No Health Connect on web.
- Web backend is **Neon Postgres**, accessed via Next.js Route Handlers (Drizzle ORM + Neon serverless driver). Auth is cookie-session auth backed by the same Neon DB (Better Auth / Auth.js-style), not Supabase Auth.

## Backend divergence — read this first

Mobile per `CLAUDE.md` + `health-cloud-sync` targets Supabase (PostgREST + GoTrue + `auth.uid()` RLS). The web track targets **Neon + first-party sync API**. Two different backends cannot both be the sync source of truth — records written on web must be readable on mobile and vice versa.

- **V1 rule:** Neon is the shared Postgres for both clients. The Next.js Route Handlers own the sync API contract in `docs/api-contract.md`; mobile adopts the same wire protocol (whether it keeps Supabase Auth or migrates fully is a separate ADR, but it must speak the same sync endpoints and `wireName`s against the same logical rows).
- If mobile stays on Supabase Postgres while web is on Neon, that is **two databases** and sync cannot converge — flag as a blocker, not a detail.
- Per-user isolation stays mandatory on both: every row scoped to `user_id`, enforced in the API layer **and** in Postgres RLS, with second-user isolation tests.

## Non-goals for web v1

1. No Health Connect / HealthKit on web.
2. Tracker, not medical device — no diagnosis or treatment copy.
3. Local IndexedDB store is the source of truth for the UI; network never blocks a user-visible write.
4. Never log health values, never put them in URLs, never send to analytics.

## PWA requirement

The web app is an **installable PWA from v1**: manifest, icons, offline shell, service worker with versioned update prompt. Installability and offline logging are launch blockers, not enhancements.

## Map

| File | Phase | Source material |
|---|---|---|
| [01-foundations](01-foundations.md) | 0 — Next.js + PWA + Neon setup | Next.js + `docs/api-contract.md` |
| [02-domain-architecture](02-domain-architecture.md) | 1 — Domain port + app architecture | `health-domain-model`, `flutter-architecture` (as spec) |
| [03-local-data-web](03-local-data-web.md) | 2 — Local data (IndexedDB) + offline shell | `health-domain-model` schema rules (as spec) |
| [04-auth-sync](04-auth-sync.md) | 3 — Auth + Neon sync API | `health-cloud-sync` protocol (as spec, Supabase specifics replaced) |
| [05-manual-entry](05-manual-entry.md) | 4 — Manual entry | `health-manual-entry` (as spec) |
| [06-visualization](06-visualization.md) | 5 — Dashboard & charts | `dataviz`, `health-data-visualization` (as spec) |
| [07-design-responsive](07-design-responsive.md) | 6 — Design parity + responsive + install UX | `flutter-design-system`, `frontend-design` (as spec) |
| [08-privacy-compliance](08-privacy-compliance.md) | 7 — Privacy & compliance (Neon processor) | `health-privacy-compliance` |
| [09-testing](09-testing.md) | 8 — Testing incl. PWA | `flutter-testing` (pyramid adapted to Next.js) |
| [10-release-launch](10-release-launch.md) | 9–10 — PWA release + post-launch | release / ops |
| [risks-milestones](risks-milestones.md) | Risks + milestones | — |

## Working order per phase

Same order as mobile: setup → domain → architecture → feature → testing → design → privacy. The Flutter skills above are read as **specifications** (rules, ranges, protocol), not as implementation guides. Where a skill names Supabase, the web track substitutes Neon + first-party API and keeps the rule, not the product.
