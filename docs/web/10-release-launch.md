# Phases 9–10 — PWA Release, Launch, Post-Launch (Next.js + Neon)

## Phase 9 — Next.js PWA release & launch

1. Hosting: Next.js-appropriate host (e.g. Vercel or equivalent) with preview deploys, TLS, and custom domain. Backend: **Neon** — production database plus a branch-per-preview-deploy strategy (or explicit equivalent), pooled `DATABASE_URL` at runtime, direct URL for migrations.
2. PWA launch blockers: Lighthouse PWA green, maskable icons + splash correct, `theme_color` set, offline shell verified from the installed icon with no network, update-prompt flow verified, iOS Safari install guidance shipped.
3. CI on every PR: `npm ci` → `tsc --noEmit` → ESLint → Vitest → Playwright (smoke, incl. offline PWA) → Lighthouse PWA → `next build` → Drizzle migration dry-run against a Neon branch. Version stamp per deploy; env-driven Neon config per environment.
4. Launch checklist: privacy policy live (naming Neon + host), deletion + export verified in prod, second-user isolation verified in prod, error reporting redacted, Cache Storage audit clean, chart downsampling + list virtualization checked on a low-end device.

## Phase 10 — Post-launch

- Release mobile + web in lockstep on contracts: `wireName`s, `docs/api-contract.md` versions, and the sync protocol never fork. A contract change lands in both clients (or behind versioning) — never in one. The Neon-vs-Supabase backend question must be resolved by ADR no later than first cross-client sync testing — see risks.
- Backlog (each re-enters the Working Order: domain → architecture → feature → tests → design → privacy):
  - Background Sync coverage / push where the platform allows.
  - Desktop density polish.
  - Chart range extensions.
