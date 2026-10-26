---
name: health-cloud-sync
description: Implements Healthie's cloud backend and sync — Supabase authentication, the Postgres schema with row-level security for per-user health data isolation, the offline-first outbox sync protocol with conflict resolution, connectivity-triggered and background sync, and session handling. This skill should be used whenever work involves sign-in, sign-up, accounts, the Supabase client, uploading or downloading health records, sync conflicts, "my data is missing on another device", offline behaviour, or the backend schema. Use it before writing any code that touches the network.
---

# Cloud Sync

Healthie syncs a personal health record across devices. The design is
**offline-first**: the local Drift database is the source of truth the UI reads
from, and the server is a replica that is brought up to date whenever the network
allows.

## Backend Choice

**Supabase** (`supabase_flutter` 2.18.3) — Postgres, GoTrue auth, and PostgREST.

Why Supabase over Firebase Firestore for this app:

- **Health data is relational and time-series.** Postgres handles range queries,
  aggregation, and per-user isolation with row-level security. Firestore's
  document model forces denormalised, pre-aggregated writes for every trend the
  dashboard shows.
- **Isolation belongs in the database.** Row-level security guarantees a user
  cannot read another user's records even if a query in the app is wrong. In
  Firestore, isolation is enforced by the app's query code — one mistake leaks
  data.
- **SQL is inspectable.** The schema and its policies can be reviewed as a
  document rather than inferred from client code.

**Do not add a second backend.** If something needs a server-side computation,
use a Postgres function or an edge function in the same Supabase project.

## Architecture

```
UI  →  Repository (domain interface)
        ↓
      Drift (local DB)  ← source of truth
        ↓ outbox table
      SyncService  →  Supabase (PostgREST)
        ↓
      Postgres  →  RLS-scoped per user
```

The repository writes locally and enqueues an outbox row. The `SyncService` drains
the outbox when it can. **No repository method ever awaits the network.**

## Authentication

Use `supabase_flutter`'s auth. It persists the session automatically (via
`shared_preferences`), so a returning user is signed in without a prompt.

```dart
await Supabase.initialize(
  url: const String.fromEnvironment('SUPABASE_URL'),
  anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
);
```

**Configuration comes from `--dart-define`, never hardcoded:**

```
flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co \
            --dart-define=SUPABASE_ANON_KEY=eyJ...
```

The anon key is a public client key and is fine in the binary. The **service role
key never ships in the app** — it bypasses row-level security entirely.

### Session handling

- `supabase_flutter` refreshes tokens automatically. Do not build a second
  refresh mechanism.
- **Listen for `authStateChange`** and route accordingly: a signed-out user goes
  to the sign-in screen; a signed-in user goes to the dashboard.
- **A 401 from the API means the session is dead.** Attempt one refresh and one
  retry. If it still fails, sign out and tell the user plainly. Do not retry
  forever and do not silently discard the session.
- **Never log tokens**, session objects, or authorisation headers — not in
  `print`, not in crash reports, not in Sentry breadcrumbs. A leaked refresh
  token is a leaked health account.

### Sign-out

On sign-out: clear the Supabase session, **and** decide what happens to the local
database. For a personal health app, the safe default is to **keep the local data
and lock it behind a re-authentication prompt**, so a shared device does not
expose one user's records to the next. If the local data is cleared, ask the user
explicitly first — local records may not have finished syncing.

## Row-Level Security

Every table is scoped to `auth.uid()`. Enable RLS and add policies:

```sql
alter table measurements enable row level security;

create policy "users read own measurements"
  on measurements for select
  using (auth.uid() = user_id);

create policy "users insert own measurements"
  on measurements for insert
  with check (auth.uid() = user_id);

create policy "users update own measurements"
  on measurements for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "users delete own measurements"
  on measurements for delete
  using (auth.uid() = user_id);
```

`delete` is allowed at the row level because Healthie uses **soft deletes** —
the delete is an `update` setting `deleted_at`, and the tombstone is what
propagates.

**Test RLS.** Create a second user in a test and verify they cannot read the
first user's rows. RLS bugs are silent and catastrophic — the app works fine and
the data leaks.

## Sync Protocol

Full detail in `references/sync-protocol.md`. The shape:

- **Push** — drain the outbox. Each row carries its `client_updated_at`.
- **Pull** — request rows with `updated_at > cursor`, where the cursor is the
  server timestamp of the last successful pull.
- **Conflict** — last-write-wins on `client_updated_at`, with **tombstones
  winning over edits**: an edit to a soft-deleted row is rejected and the
  client re-applies the deletion.
- **Cursor** — stored in the local database, not in shared preferences, so it is
  part of the same transaction that applies pulled changes.

Every pulled row is written to the local DB and applied to the UI by the reactive
query. **The pull never blocks the UI.**

## Triggering Sync

Three triggers, in priority order:

1. **After a local write** — if the device is online, sync soon. A short debounce
   (a few seconds) coalesces a burst of entries into one push.
2. **On connectivity restored** — `connectivity_plus` reports network state.
   Note that connectivity means "a network interface exists", not "the internet
   is reachable" — a captive portal still reports connected. Handle the failure
   and retry.
3. **Periodically** — `workmanager` runs a periodic background sync. It opens its
   own database connection in the background isolate; it cannot use the app's
   Riverpod container.

Retries use exponential backoff with jitter. Give up after a bounded number of
attempts and leave the rows in the outbox — **the outbox is a durable queue, not
a retry buffer that discards**.

## What Sync Must Never Do

- **Block a user-visible write.** A user on a train with no signal must be able
  to log their weight and see it immediately.
- **Delete local data because the server says so** — except via a tombstone
  change that was genuinely received.
- **Fail loudly to the user** for a background sync failure. A failed sync is
  logged and retried silently; the user sees a small "not synced" indicator at
  most.
- **Send data the user did not ask to sync.** Sync the health records. Do not
  sync raw Health Connect payloads that were never turned into Healthie records.

## Backfill and Destructive Server Changes

- **Never mutate a shipped server migration.** Add a new migration instead.
- **Adding a nullable column** is safe — backfill lazily.
- **Renaming a column** requires an expand/contract migration: add the new
  column, dual-write, backfill, switch reads, then drop the old one.
- **Changing a `wireName`** breaks sync for every existing record. The
  `wireName` is a permanent contract (see the `health-domain-model` skill).

## Privacy

Health records synced to a server are **sensitive personal data**. See the
`health-privacy-compliance` skill for the full obligations: what the privacy
policy must say, encryption, retention, deletion, and export.

At minimum:

- **TLS everywhere.** Supabase provides HTTPS; never point the client at a
  non-TLS endpoint.
- **No health data in logs, analytics, or crash reports.** Check the payloads
  before wiring any error-reporting SDK.
- **A full delete path** — the user can delete their account and all server data.
  This is a legal requirement, not a feature.

## Verification Checklist

- [ ] A write with no network succeeds and appears in the UI instantly.
- [ ] The write reaches the server once connectivity returns.
- [ ] A second device sees the record after a pull.
- [ ] Signing in on a second device does not show another user's data (RLS).
- [ ] Editing the same record on two devices converges to one value, with no
      record duplication.
- [ ] A delete on one device removes the record on the other.
- [ ] A tombstone wins over a concurrent edit.
- [ ] Tokens never appear in logs.
- [ ] Account deletion removes server data.

## Reference Files

- `references/sync-protocol.md` — the full push/pull protocol, the cursor
  handling, conflict resolution rules, and the Dart implementation sketch.
- `references/backend-schema.md` — the Postgres schema, indexes, RLS policies,
  and the sync RPC functions.
