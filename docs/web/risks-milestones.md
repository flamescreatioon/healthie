# Risks + Milestones (Next.js PWA + Neon)

## Top risks

1. **Neon-vs-Supabase backend split (biggest)** — mobile per `CLAUDE.md` targets Supabase; web targets Neon. Two databases cannot converge, and Auth/RLS/sync helpers do not transfer. Mitigation: decide by ADR before Phase 3 whether Neon becomes the shared Postgres; until then, web implements the sync contract on Neon and mobile conformance is untested — flag as a launch blocker for cross-device sync.
2. **Auth responsibility shift** — no GoTrue on web. Sessions, cookies, refresh, and revocation are first-party code backed by Neon tables. Mitigation: spike in Phase 0, security-review the session handler, test expiry/refresh/theft-rotation explicitly.
3. **RLS without Supabase helpers** — Postgres RLS still applies on Neon but the `auth.uid()` wiring is gone; every handler must set the session context correctly. Mitigation: enforce `user_id` scoping in the app layer **and** RLS in Postgres, with crafted-request second-user tests in CI.
4. **Contract drift between Dart and TypeScript** — two codebases, one protocol. Mitigation: `docs/api-contract.md` as authority, shared test vectors (catalog, conversions, local-day cases, sync vectors) implemented in both suites, lockstep releases on any contract change.
5. **Service-worker + health-data leakage** — an over-broad runtime cache puts health payloads in Cache Storage outside IndexedDB's lifecycle. Mitigation: shell-only caching (Phase 2), Cache Storage audit in CI (Phase 8).
6. **Offline/background gap on web** — Background Sync is not universal (notably iOS Safari). Set the expectation early: sync while open + on reconnect/focus/Background-Sync; closed-tab sync best-effort elsewhere.
7. **IndexedDB fragility** (private windows, storage pressure, version upgrades) — handle degradation explicitly and test migrations; never lose a queued outbox row silently.
8. **Design divergence** — enforce ported tokens and shared component names; every new screen passes the design checklist against the Flutter spec.

## Milestones

- **M1** Next.js PWA scaffold green (`tsc`, lint, test, `next build`, Lighthouse PWA baseline) + spikes (IndexedDB, Neon Drizzle round-trip, cookie auth).
- **M2** Domain/arch port with fake repos (+ backend-split ADR logged).
- **M3** Offline logging in the installed PWA persists across reload.
- **M4** Two-browser sync converges against Neon (and matches the wire protocol mobile will use).
- **M5** Dashboard parity, light + dark.
- **M6** Responsive + accessibility + install-UX pass.
- **M7** Privacy / export / deletion verified on Neon.
- **M8** Prod PWA deploy + launch checklist (installable, offline shell, audits green).
