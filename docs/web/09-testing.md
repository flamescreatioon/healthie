# Phase 8 — Testing (Next.js PWA + Neon)

Source: `flutter-testing` pyramid adapted to Next.js: ~70% unit / 25% component / 5% E2E. Stack: Vitest + Testing Library + Playwright (or equivalent), plus Lighthouse PWA audits.

## Goal

Same bar as mobile — typecheck clean, lint clean, tests green before any phase is done — with PWA- and Neon-specific coverage.

## Steps

1. Unit (Vitest): conversions both directions at boundaries, local-day grouping across DST / leap / midnight / timezone-flight, validation bounds, tombstone-wins, outbox compaction. Fixed timezones and injected clocks; no `Date.now()` in domain functions.
2. Repository tests against a real (in-memory/fake-indexedDB) store asserting outbox rows, not just saved values. Migration tests for every Dexie schema version. Sync-protocol tests (push/pull/cursor/conflict vectors) run against a Neon test branch so both clients' vectors stay aligned.
3. Component tests (Testing Library) per screen: loading, empty, populated, error, plus primary-action interaction. Prefer accessible-role/test-id queries over copy-sensitive text finders.
4. E2E (Playwright) kept few and stable: install-context launch → dashboard, log a value → appears in list, reload → value persists, **offline (context.setOffline + installed PWA) → log → online → syncs**, sign-in on a second profile shows no cross-user data. Visual snapshots sparingly, for stable components only.
5. PWA checks in CI: Lighthouse PWA category (installable, splash, theme-color, maskable icons, offline shell), service-worker update flow (old → new version prompts, no stranded clients), and a Cache Storage audit asserting no health payload is cached.
6. Manual QA: decimal-comma locale, dark mode, 200% scale, keyboard-only flow, screen-reader chart summaries, Add-to-Home-Screen on iOS Safari and install on Chromium.

## Exit criteria

- [ ] Boundary tests for conversions, dates, validation, conflicts.
- [ ] Outbox behaviour asserted on every repository change.
- [ ] Four-state component tests on every new screen.
- [ ] Offline-PWA E2E passes; Lighthouse PWA green.
- [ ] `tsc --noEmit` + ESLint + all tests green before any phase is done.
