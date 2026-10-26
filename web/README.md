# Healthie Web (`web/`)

Local-first Progressive Web App (PWA) for personal vitals, blood pressure, weight, trends, and clinical-grade self-tracking, engineered in strict alignment with `docs/web/01-foundations.md` through `10-release-launch.md` and `docs/adr/0006-backend-neon-sync-convergence.md`.

## Pinned Stack Matrix

| Concern | Technology | Version |
| --- | --- | --- |
| Framework & Routing | Next.js (App Router) | `^15.5.0` |
| UI Runtime | React / React DOM | `^19.1.0` |
| Language | TypeScript (`strict: true`, `noUncheckedIndexedAccess: true`) | `^5.8.0` |
| Styling | Tailwind CSS v4 + CSS Custom Properties (`globals.css`) | `^4.1.0` |
| Local Offline Database | IndexedDB via `dexie` | `^4.0.11` |
| Cloud Database | **Neon** Serverless Postgres (`@neondatabase/serverless`) + Drizzle ORM | `^1.0.0` / `^0.41.0` |
| Async State | `@tanstack/react-query` | `^5.72.0` |
| Forms & Validation | `react-hook-form` + `zod` + pure domain validators | `^7.55.0` / `^3.24.2` |
| Charts | `recharts` + accessible SVG sparklines & `.sr-only` data tables | `^2.15.1` |
| Testing | `vitest`, `@testing-library/react`, `fake-indexeddb`, `@playwright/test` | `^3.1.1` |

## Architecture & Non-Negotiable Invariants

1. **Pure Domain Layer (`src/domain/`)**: Zero React, Next.js, Dexie, Neon, Drizzle, or network imports. Verified in CI by `npm run check:layering`.
2. **Canonical Units in Storage & Wire**:
   - Blood Pressure: `mmHg` (`systolic`, `diastolic`, `pulse` in `bpm`)
   - Weight: `kg` (UI converts to/from `lb` via `2.20462262185` on display/input only)
   - Heart Rate: `bpm`
   - SpO2: `%`
   - Body Temperature: `°C` (UI converts to/from `°F` via `C * 9 / 5 + 32` on display/input only)
   - Blood Glucose: `mg/dL` (UI converts to/from `mmol/L` via `/ 18.0182` on display/input only)
3. **Local-Day Grouping Rule**: Measurements are grouped by local calendar day (`startOfLocalDay` / `toLocalDayString`) in the user's local timezone while stored in UTC ISO-8601.
4. **Atomic Local Writes & Outbox Compaction (`src/data/`)**: Every measurement save/delete writes to `measurements` and `syncOutbox` in a single Dexie transaction. Deleting a record with a pending `'upsert'` compacts the outbox entry into `'delete'`.
5. **Dual-Layer Per-User Isolation (`src/server/db/`)**: Neon Postgres enforces both explicit `WHERE user_id = :sessionUserId` predicates and PostgreSQL Row-Level Security (`FORCE ROW LEVEL SECURITY` with `app.current_user_id`).
6. **Shell-Only Service Worker (`public/sw.js`)**: Never caches `/api/*` health payloads in browser Cache Storage. Verified in CI by `npm run check:sw-cache`.

## Getting Started

```bash
cd web
cp .env.example .env.local
npm install
npm run dev
```

### Verification Suite

```bash
npm run verify
```

Runs:
- `npm run typecheck` (`tsc --noEmit`)
- `npm run check:layering` (verifies domain purity & client/server boundaries)
- `npm run check:sw-cache` (verifies `/api/*` exclusion from Service Worker Cache Storage)
- `npm run test` (Vitest unit, repository, sync, RLS isolation, and component tests)
- `npm run build` (Next.js production build)
