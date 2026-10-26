# Sync Protocol

## Model

Each synced row carries four timestamps/identifiers:

| Field | Set by | Purpose |
|---|---|---|
| `id` | Client (UUID) | Stable identity across devices |
| `user_id` | Server (RLS) | Owner |
| `client_updated_at` | Client device clock | **Conflict comparison** |
| `updated_at` | Server clock | **Change-log cursor** |
| `deleted_at` | Client (nullable) | Tombstone |

`updated_at` is stamped by the server on every accepted write and is what the
pull cursor tracks. `client_updated_at` is the device's own clock and is used
only to decide which of two concurrent edits wins.

Using the server clock for the cursor avoids the classic problem of a device with
a wrong clock silently re-syncing everything forever. Using the client clock for
conflict comparison means the *user's* edit order is respected rather than the
network's arrival order.

## Push (local → server)

1. Claim a batch of outbox rows. The claim is a conditional update so two
   concurrent sync runs never process the same row.
2. Send them as a batched RPC (`sync_push`), not row-by-row requests.
3. The server applies each row with LWW semantics and returns a per-row result.
4. Mark each outbox row done, or record the failure and leave it queued.

```dart
Future<void> _pushBatch(List<SyncOutboxData> batch) async {
  final payload = batch
      .map((row) => {
            'entity_type': row.entityType,
            'entity_id': row.entityId,
            'operation': row.operation,
            'payload': jsonDecode(row.payload),
            'client_updated_at': row.queuedAt.toUtc().toIso8601String(),
          })
      .toList();

  final result = await _supabase.rpc('sync_push', params: {'rows': payload});
  // result: list of { entity_id, status } where status is 'applied' | 'conflict' | 'rejected'
}
```

Server-side push semantics:

- If no row exists with that `(user_id, id)` → insert.
- If a row exists and `deleted_at` is set → the tombstone wins. An edit to a
  deleted row is **rejected**; the client learns the record is deleted and
  applies the deletion locally.
- If a row exists and `deleted_at` is null → apply the incoming row only if
  `excluded.client_updated_at > target.client_updated_at`. Otherwise **conflict**:
  the server row wins and is returned to the client.
- A `delete` operation always applies, regardless of timestamps, unless the
  server row is newer and also deleted (in which case it is already deleted —
  idempotent no-op).

## Pull (server → local)

1. Read the cursor from the local database (not shared preferences).
2. Request all rows with `updated_at > cursor`, ordered by `updated_at`.
3. Apply each row locally, in one transaction.
4. Advance the cursor to the server timestamp of the last row applied.
5. Store the cursor **in the same transaction** as the applied rows. If the app
   crashes mid-pull, the cursor and the data stay consistent.

```dart
Future<void> _pull() async {
  final cursor = await _dao.getSyncCursor();

  final rows = await _supabase.rpc('sync_pull', params: {
    'since': cursor?.toUtc().toIso8601String(),
  });

  final newCursor = rows.isEmpty
      ? cursor
      : DateTime.parse(rows.last['updated_at'] as String);

  await _db.transaction(() async {
    for (final row in rows.cast<List<Map<String, dynamic>>>()) {
      await _applyRemoteRow(row);
    }
    await _dao.setSyncCursor(newCursor);
  });
}
```

**Use the server's own watermark, not the local clock.** If the server returns a
`server_now` value alongside the rows, use that as the cursor when no rows were
returned — otherwise a device that syncs twice in a row with no new data will
re-fetch the same window forever.

## Conflict Resolution

The rules, in order:

1. **Same value, both devices** → no conflict; both converge. Common with
   Health Connect imports arriving on two devices.
2. **Different value, one is newer** → the newer wins. The losing device
   receives the winning row in the next pull and overwrites its local copy.
3. **Different value, same timestamp** → the server's copy wins (deterministic
   tiebreak). Rare, but it must be deterministic or two devices diverge forever.
4. **Edit vs. delete** → the delete wins. Health data deletions should be
   respected: if a user deleted a record, resurrecting it because another device
   edited it is wrong.
5. **Delete vs. delete** → idempotent no-op.

### Surfacing conflicts to the user

Do not show a modal for every conflict. A conflict on a health metric is almost
always benign, and a wall of conflict dialogs trains the user to dismiss them
without reading.

- **Auto-resolve silently** for cases 1–3 and 5.
- **Surface a non-blocking notice** for case 4 (a record the user edited
  elsewhere was deleted here), so the deletion is not a surprise.

## Retry and Backoff

- Exponential backoff with jitter: 2s, 4s, 8s, 16s, 32s, capped at 5 minutes.
- Jitter is not optional — without it, every device that lost connectivity at
  the same moment reconnects at the same moment and stampedes the server.
- Give up after a bounded number of attempts, but **leave the rows in the
  outbox**. The outbox is durable. A failed row is retried on the next sync
  trigger.
- Distinguish retryable failures (network, 5xx, 429) from permanent ones
  (400, 403, 422). A 400 means the payload is wrong — retrying it forever
  wedges the queue. Quarantine permanent failures after a few attempts and
  report them.

## The Outbox

The outbox is what makes sync crash-safe. The data write and the outbox
enqueue happen in **one transaction**:

```dart
Future<void> saveWeight(WeightEntry entry) async {
  await _db.transaction(() async {
    await _dao.upsert(entry);
    await _outbox.enqueue(
      entityType: 'measurements',
      entityId: entry.id,
      operation: SyncOperation.upsert,
      payload: entry.toJson(),
    );
  });
}
```

If the app crashes between the data write and the outbox write, the record
never uploads. One transaction removes that window entirely.

**Compaction.** Repeated edits to the same record enqueue multiple outbox rows.
Compact them before pushing: keep only the latest row per `(entity_type,
entity_id)`, unless the latest is a delete — then the delete must win, because a
delete followed by a stale upsert would resurrect the record.

## Claiming Outbox Rows

Two concurrent sync runs (a foreground trigger and a background worker) must not
process the same row. Claim with a conditional update:

```sql
UPDATE sync_outbox
SET is_processing = 1, last_attempt_at = :now
WHERE id IN (
  SELECT id FROM sync_outbox
  WHERE is_processing = 0
  ORDER BY queued_at
  LIMIT :limit
)
RETURNING *;
```

The `WHERE is_processing = 0` inside the subquery is what makes the claim
atomic. A read-then-write in Dart is not — two runs can both read the same rows
before either writes.

## Sync Triggers

| Trigger | Behaviour |
|---|---|
| After a local write | Debounce 3–5s, then sync if online |
| Connectivity restored | Sync immediately |
| App foregrounded | Sync if the last sync is older than a few minutes |
| `workmanager` periodic | Sync on the platform's schedule |
| Manual "Sync now" | Sync immediately, show a spinner |

The foreground trigger is the one that matters most. Users change devices far
less often than they change phones, so foreground-sync-on-open covers most real
cases.

## Background Sync with workmanager

The callback runs in a **separate isolate**. It cannot see the app's Riverpod
providers or the app's open database. It must:

1. Create its own `SupabaseClient` (initialising the plugin again if needed).
2. Open its own `AppDatabase` connection.
3. Run the push and pull.
4. Close the database.

```dart
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final db = AppDatabase();
    try {
      final sync = SyncService(db: db, supabase: await _buildClient());
      await sync.runOnce();
      return true;
    } catch (_) {
      return false;   // retry
    } finally {
      await db.close();
    }
  });
}
```

Android may delay or skip background work. Treat background sync as a bonus, not
a guarantee — the foreground trigger is what makes sync reliable.
