/**
 * Client-side Offline-First Sync Engine (`docs/web/04-auth-sync.md`).
 *
 * - Drains `syncOutbox` to `/api/sync/push`
 * - Pulls remote changes from `/api/sync/pull?since=...` and applies them in
 *   a SINGLE Dexie transaction alongside the updated sync cursor.
 * - On 401: attempts one `/api/auth/refresh` + one retry, then marks signed out.
 * - Triggers: post-write debounce, `online` event, `visibilitychange`, in-tab
 *   interval, and Service Worker Background Sync (`sync` event).
 */

import { measurementFromJson, type MeasurementWireJson } from '@/domain';
import { getLocalDb, type HealthieLocalDb } from './db';

export type SyncStateKind = 'idle' | 'syncing' | 'synced' | 'offline' | 'error';

export interface SyncStatusSnapshot {
  readonly state: SyncStateKind;
  readonly pendingCount: number;
  readonly lastSyncedAt: string | null;
  readonly syncEnabled: boolean;
  readonly errorMessage: string | null;
}

const SYNC_CURSOR_KEY = 'last_sync_cursor';
const SYNC_ENABLED_KEY = 'sync_enabled';
const LAST_SYNCED_AT_KEY = 'last_synced_at';

export async function isSyncOptedIn(db: HealthieLocalDb = getLocalDb()): Promise<boolean> {
  const row = await db.syncMeta.get(SYNC_ENABLED_KEY);
  return row?.value === 'true';
}

export async function setSyncOptIn(
  enabled: boolean,
  db: HealthieLocalDb = getLocalDb(),
): Promise<void> {
  await db.syncMeta.put({
    key: SYNC_ENABLED_KEY,
    value: enabled ? 'true' : 'false',
    updatedAt: new Date().toISOString(),
  });
}

export async function getSyncCursor(
  db: HealthieLocalDb = getLocalDb(),
): Promise<string | null> {
  const row = await db.syncMeta.get(SYNC_CURSOR_KEY);
  return row?.value ?? null;
}

export async function getLastSyncedAt(
  db: HealthieLocalDb = getLocalDb(),
): Promise<string | null> {
  const row = await db.syncMeta.get(LAST_SYNCED_AT_KEY);
  return row?.value ?? null;
}

async function fetchWithOneRefreshRetry(
  input: string,
  init: RequestInit,
  fetchImpl: typeof fetch,
): Promise<Response> {
  const first = await fetchImpl(input, {
    ...init,
    credentials: 'include',
  });
  if (first.status !== 401) return first;

  // Attempt one session refresh + one retry per `docs/web/04-auth-sync.md`
  const refreshRes = await fetchImpl('/api/auth/refresh', {
    method: 'POST',
    credentials: 'include',
  });
  if (!refreshRes.ok) {
    return first;
  }
  return fetchImpl(input, {
    ...init,
    credentials: 'include',
  });
}

export async function runSyncCycle(options?: {
  db?: HealthieLocalDb;
  fetchImpl?: typeof fetch;
  force?: boolean;
}): Promise<{
  pushed: number;
  pulled: number;
  cursor: string | null;
  unauthorized?: boolean;
}> {
  const db = options?.db ?? getLocalDb();
  const fetchImpl = options?.fetchImpl ?? fetch;

  if (!options?.force) {
    const enabled = await isSyncOptedIn(db);
    if (!enabled) {
      return { pushed: 0, pulled: 0, cursor: await getSyncCursor(db) };
    }
  }

  // 1. Push pending outbox entries
  const outboxRows = await db.syncOutbox.orderBy('queuedAt').toArray();
  let pushedCount = 0;

  if (outboxRows.length > 0) {
    const operations = outboxRows.map((row) => ({
      entity_type: row.entityType,
      entity_id: row.entityId,
      operation: row.operation,
      payload: JSON.parse(row.payload) as Record<string, unknown>,
      client_updated_at: row.clientUpdatedAt,
    }));

    const pushRes = await fetchWithOneRefreshRetry(
      '/api/sync/push',
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ rows: operations }),
      },
      fetchImpl,
    );

    if (pushRes.status === 401) {
      return { pushed: 0, pulled: 0, cursor: await getSyncCursor(db), unauthorized: true };
    }
    if (!pushRes.ok) {
      throw new Error(`Sync push failed with status ${pushRes.status}`);
    }

    const pushBody = (await pushRes.json()) as {
      results: Array<{
        entity_id: string | null;
        status: 'applied' | 'conflict' | 'rejected' | 'invalid';
        server_row?: MeasurementWireJson;
      }>;
      server_timestamp: string;
    };

    await db.transaction('rw', db.measurements, db.syncOutbox, async () => {
      for (const item of pushBody.results) {
        if (!item.entity_id) continue;
        if (item.status === 'applied') {
          pushedCount += 1;
          await db.syncOutbox.delete(item.entity_id);
          const localRow = await db.measurements.get(item.entity_id);
          if (localRow) {
            await db.measurements.put({ ...localRow, isSynced: true });
          }
        } else if (
          (item.status === 'conflict' || item.status === 'rejected') &&
          item.server_row
        ) {
          // Server row or tombstone won; apply server truth locally and clear outbox
          const authoritative = measurementFromJson({
            ...item.server_row,
            is_synced: true,
          });
          await db.measurements.put(authoritative);
          await db.syncOutbox.delete(item.entity_id);
        }
      }
    });
  }

  // 2. Pull server changes since cursor
  const currentCursor = await getSyncCursor(db);
  const query = currentCursor ? `?since=${encodeURIComponent(currentCursor)}` : '';
  const pullRes = await fetchWithOneRefreshRetry(
    `/api/sync/pull${query}`,
    { method: 'GET' },
    fetchImpl,
  );

  if (pullRes.status === 401) {
    return {
      pushed: pushedCount,
      pulled: 0,
      cursor: currentCursor,
      unauthorized: true,
    };
  }
  if (!pullRes.ok) {
    throw new Error(`Sync pull failed with status ${pullRes.status}`);
  }

  const pullBody = (await pullRes.json()) as {
    changes: Array<{
      entity_type: string;
      entity_id: string;
      operation: 'upsert' | 'delete';
      payload: MeasurementWireJson;
      server_updated_at: string;
    }>;
    server_timestamp: string;
  };

  let pulledCount = 0;

  // Apply pulled rows + advance cursor in a SINGLE atomic Dexie transaction
  await db.transaction(
    'rw',
    db.measurements,
    db.syncOutbox,
    db.syncMeta,
    async () => {
      for (const change of pullBody.changes) {
        if (change.entity_type !== 'measurements') continue;
        const pendingOutbox = await db.syncOutbox.get(change.entity_id);
        const incoming = measurementFromJson({
          ...change.payload,
          is_synced: true,
        });

        if (change.operation === 'delete' || incoming.deletedAt) {
          // Tombstone always wins over local state or pending edit
          await db.measurements.put(incoming);
          if (pendingOutbox) {
            await db.syncOutbox.delete(change.entity_id);
          }
          pulledCount += 1;
          continue;
        }

        if (pendingOutbox) {
          // If local has a pending delete, local tombstone wins
          if (pendingOutbox.operation === 'delete') continue;
          // Compare timestamps for LWW
          const pendingMs = new Date(pendingOutbox.clientUpdatedAt).getTime();
          const incomingMs = new Date(incoming.updatedAt).getTime();
          if (pendingMs > incomingMs) continue;
        }

        const existingLocal = await db.measurements.get(change.entity_id);
        if (existingLocal?.deletedAt) {
          // Local tombstone wins
          continue;
        }

        await db.measurements.put(incoming);
        pulledCount += 1;
      }

      const nowIso = new Date().toISOString();
      await db.syncMeta.put({
        key: SYNC_CURSOR_KEY,
        value: pullBody.server_timestamp,
        updatedAt: nowIso,
      });
      await db.syncMeta.put({
        key: LAST_SYNCED_AT_KEY,
        value: nowIso,
        updatedAt: nowIso,
      });
    },
  );

  return {
    pushed: pushedCount,
    pulled: pulledCount,
    cursor: pullBody.server_timestamp,
  };
}

export async function requestBackgroundSync(): Promise<void> {
  if (typeof window === 'undefined' || !('serviceWorker' in navigator)) return;
  try {
    const registration = await navigator.serviceWorker.ready;
    if ('sync' in registration) {
      await (
        registration as ServiceWorkerRegistration & {
          sync: { register(tag: string): Promise<void> };
        }
      ).sync.register('healthie-outbox-sync');
    }
  } catch {
    // Background Sync API is not supported on iOS Safari / some browsers;
    // foreground triggers (online, visibilitychange, interval) handle sync.
  }
}
