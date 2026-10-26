# Phase 2 — Local Data + Offline Shell (IndexedDB + PWA)

Source spec: `health-domain-model` schema rules. Mobile equivalent: Drift tables; web equivalent: Dexie.js over IndexedDB with the same shape, plus the PWA offline shell.

## Goal

IndexedDB is the web source of truth for the UI; the installed PWA works fully offline for logging and review. Same schema semantics as mobile, same offline-first write path.

## Steps

1. Mirror the Drift tables in Dexie stores: UTC `recordedAt`, denormalized `localDay` at local midnight, explicit unit column, `deletedAt` tombstones, indexes on `recordedAt` (and `localDay` where the dashboard queries by day).
2. Keep writes atomic at the app level: measurement write + outbox enqueue in a single Dexie transaction. A write that lands without its outbox row is a sync bug.
3. Version the schema from v1 with Dexie versioned migrations, mirroring mobile's permanent-migration discipline. Every schema change needs a migration plus a test; mobile and web version their stores independently but must never disagree on `wireName`s or canonical units.
4. PWA offline shell: service worker precaches the app shell (routes, static assets) so launch, dashboard, track, and history render offline from IndexedDB. Health-record API responses are **never** cached in Cache Storage — offline reads come from IndexedDB only. Document the cache allow/deny list next to the worker registration.
5. Verify the offline-first path: write → local read updates UI via TanStack Query invalidation/subscription → outbox drains later. The network is never on the critical path of a user-visible write — including with the service worker killed and with the app launched from the installed icon with no connectivity.
6. Never hard-delete user data; deletions are soft + syncable tombstones.

## Exit criteria

- [ ] Offline logging works and appears instantly in the UI, including from the installed PWA with no network.
- [ ] Data survives browser reload (and private-window degradation is handled explicitly).
- [ ] Service-worker cache audit: shell cached, no health payload in Cache Storage.
- [ ] Every write enqueues an outbox row (asserted in tests).
- [ ] Migration tests cover every schema version.
