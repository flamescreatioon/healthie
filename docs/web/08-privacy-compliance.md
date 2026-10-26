# Phase 7 — Privacy & Compliance (Next.js + Neon Track)

Skill: `health-privacy-compliance` (applies in full; Play-only artifacts N/A; Supabase processor references replaced with Neon).

## Goal

All data-handling obligations hold in the Next.js PWA on Neon, including browser-specific and service-worker leak surfaces.

## Play items that are N/A on web

- No Health Connect permission declarations, no rationale screen, no health apps declaration, no data safety form.
- Document the N/A explicitly at launch so a later Android submission does not inherit web assumptions.

## Processor change: Neon (not Supabase)

- The privacy policy names **Neon** as the Postgres processor (plus the app host) — not Supabase. Record Neon's DPA and the chosen region/residency facts in this phase; the policy states where the server stores the data.
- Neon specifics to verify: TLS in transit (required, no plaintext), encryption at rest, branch/point-in-time-recovery retention (backups must expire on the same schedule as the primary store), and that dropped preview branches actually delete their data.

## Steps (all still required)

1. Publish a live privacy policy URL (or route): what is collected, where it goes (device IndexedDB by default; Neon on sync opt-in), retention, export, encryption, no sale / no advertising, contact, effective date + changelog.
2. Enforce data-handling rules with Next.js + PWA specifics: no health values in logs, analytics, error breadcrumbs, or URLs (route params, search params, and referrers — audit what the host and any error SDK capture); no health payloads in **Cache Storage** (shell-only caching per Phase 2 — audit it); generic route names in telemetry (`/metric/[type]`, never values); HTTPS only; explicit opt-in sync; separate consent for any future sharing.
3. Implement and verify the account-deletion cascade in Neon (every table, verified by query — including auth/session rows and orphaned outbox rows), offline-capable JSON + CSV export with schema version (generated client-side from IndexedDB), and stated retention for inactive accounts.
4. Show the medical disclaimer where readings appear. Thresholds stated factually; no diagnosis, no treatment advice, no medical-device claims.
5. GDPR/PIPL readiness: explicit-consent basis, processor DPA(s), residency statement, access / correct / export / delete paths.

## Exit criteria

- [ ] Privacy policy live, naming Neon + host, covering every required point.
- [ ] No health values in logs, analytics, crash reports, URLs, or Cache Storage (audited — browser history, devtools, and server logs raise the stakes on web).
- [ ] Account deletion verified in Neon (all tables, incl. sessions).
- [ ] Preview-branch data deletion verified.
- [ ] Export works offline and round-trips.
- [ ] Sync is opt-in; opting out keeps local data.
