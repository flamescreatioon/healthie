import { beforeEach, describe, expect, it } from 'vitest';
import { HealthieLocalDb } from '@/data/db';
import {
  DexieMeasurementRepository,
  DexieProfileRepository,
  DexieReminderRepository,
} from '@/data/dexie-repositories';
import {
  buildJsonExport,
  parseJsonExport,
  buildCsvExport,
} from '@/data/export';
import {
  applySyncPushBatch,
  pullSyncChanges,
  deleteAccountCascade,
  resetServerStoreForTests,
} from '@/server/db/store';
import type { Measurement } from '@/domain';

describe('Data Layer — Dexie Atomic Outbox, Compaction & Offline Export', () => {
  let db: HealthieLocalDb;
  let measurementsRepo: DexieMeasurementRepository;
  let profileRepo: DexieProfileRepository;
  let reminderRepo: DexieReminderRepository;

  beforeEach(async () => {
    db = new HealthieLocalDb(`HealthieTestDb_${Date.now()}_${Math.random()}`);
    measurementsRepo = new DexieMeasurementRepository(db);
    profileRepo = new DexieProfileRepository(db);
    reminderRepo = new DexieReminderRepository(db);
  });

  it('writes measurement and syncOutbox entry atomically and compacts outbox on delete', async () => {
    const nowIso = '2026-05-15T09:00:00.000Z';
    const m: Measurement = {
      id: 'm-atomic-1',
      metricType: 'blood_pressure',
      value: 122,
      unit: 'mmHg',
      secondaryValue: 78,
      secondaryUnit: 'mmHg',
      tertiaryValue: 64,
      tertiaryUnit: 'bpm',
      recordedAt: nowIso,
      localDay: '2026-05-15',
      createdAt: nowIso,
      updatedAt: nowIso,
      source: 'manual',
      isSynced: false,
      deletedAt: null,
      context: { posture: 'sitting', arm: 'left' },
    };

    await measurementsRepo.save(m);

    const outboxAfterSave = await measurementsRepo.getOutbox();
    expect(outboxAfterSave).toHaveLength(1);
    expect(outboxAfterSave[0]?.entityId).toBe('m-atomic-1');
    expect(outboxAfterSave[0]?.operation).toBe('upsert');

    // Deleting a record that has a pending upsert compacts the outbox entry to 'delete'
    const deletedAtIso = '2026-05-15T09:05:00.000Z';
    await measurementsRepo.softDelete('m-atomic-1', deletedAtIso);

    const activeById = await measurementsRepo.getById('m-atomic-1');
    expect(activeById).toBeNull();

    const outboxAfterDelete = await measurementsRepo.getOutbox();
    expect(outboxAfterDelete).toHaveLength(1);
    expect(outboxAfterDelete[0]?.entityId).toBe('m-atomic-1');
    expect(outboxAfterDelete[0]?.operation).toBe('delete');

    const parsedPayload = JSON.parse(outboxAfterDelete[0]!.payload) as Record<
      string,
      unknown
    >;
    expect(parsedPayload.deleted_at).toBe(deletedAtIso);
  });

  it('exports full offline JSON and CSV and round-trips schema_version: 1 JSON', async () => {
    const nowIso = '2026-05-15T10:00:00.000Z';
    await measurementsRepo.save({
      id: 'm-export-1',
      metricType: 'weight',
      value: 71.2,
      unit: 'kg',
      recordedAt: nowIso,
      localDay: '2026-05-15',
      createdAt: nowIso,
      updatedAt: nowIso,
      source: 'manual',
      isSynced: false,
      deletedAt: null,
      context: { notes: 'Post-run' },
    });

    const currentProfile = await profileRepo.getProfile();
    await profileRepo.saveProfile({
      ...currentProfile,
      displayName: 'Alex Tester',
      heightCm: 176,
    });

    await reminderRepo.saveReminder({
      id: 'rem-1',
      kind: 'morning_blood_pressure',
      title: 'Morning BP',
      metricType: 'blood_pressure',
      hour: 8,
      minute: 0,
      enabled: true,
      updatedAt: nowIso,
    });

    const measurements = await measurementsRepo.list();
    const profile = await profileRepo.getProfile();
    const goals = await profileRepo.listGoals();

    const rawJson = buildJsonExport({
      measurements,
      profile,
      goals,
      exportedAtIso: nowIso,
    });

    const parsed = parseJsonExport(rawJson);
    expect(parsed.schemaVersion).toBe(1);
    expect(parsed.measurements).toHaveLength(1);
    expect(parsed.measurements[0]?.id).toBe('m-export-1');
    expect(parsed.measurements[0]?.value).toBe(71.2);

    const csv = buildCsvExport(parsed.measurements);
    expect(csv).toContain('id,metric_type,value,unit');
    expect(csv).toContain('m-export-1');
    expect(csv).toContain('71.2');
  });
});

describe('Server Sync & Multi-Tenant RLS Isolation', () => {
  beforeEach(() => {
    resetServerStoreForTests();
  });

  it('enforces Last-Write-Wins (LWW) and Tombstone-Wins conflict resolution', async () => {
    const userA = 'user-a-uuid';

    // 1. Initial upsert at 10:00
    await applySyncPushBatch({
      authenticatedUserId: userA,
      operations: [
        {
          entity_type: 'measurements',
          entity_id: 'm-sync-1',
          operation: 'upsert',
          client_updated_at: '2026-05-15T10:00:00.000Z',
          payload: {
            id: 'm-sync-1',
            metric_type: 'weight',
            value: 74.0,
            unit: 'kg',
            recorded_at: '2026-05-15T10:00:00.000Z',
            local_day: '2026-05-15',
            created_at: '2026-05-15T10:00:00.000Z',
            updated_at: '2026-05-15T10:00:00.000Z',
            source: 'manual',
            context: {},
          },
        },
      ],
    });

    // 2. Stale edit at 09:55 must be ignored by LWW
    const staleResult = await applySyncPushBatch({
      authenticatedUserId: userA,
      operations: [
        {
          entity_type: 'measurements',
          entity_id: 'm-sync-1',
          operation: 'upsert',
          client_updated_at: '2026-05-15T09:55:00.000Z',
          payload: {
            id: 'm-sync-1',
            metric_type: 'weight',
            value: 99.9,
            unit: 'kg',
            recorded_at: '2026-05-15T10:00:00.000Z',
            local_day: '2026-05-15',
            created_at: '2026-05-15T10:00:00.000Z',
            updated_at: '2026-05-15T09:55:00.000Z',
            source: 'manual',
            context: {},
          },
        },
      ],
    });
    expect(staleResult.results[0]?.status).toBe('conflict');

    const afterStale = await pullSyncChanges({
      authenticatedUserId: userA,
      since: null,
    });
    expect(afterStale.changes).toHaveLength(1);
    expect(afterStale.changes[0]?.payload.value).toBe(74.0);

    // 3. Delete tombstone at 10:05
    await applySyncPushBatch({
      authenticatedUserId: userA,
      operations: [
        {
          entity_type: 'measurements',
          entity_id: 'm-sync-1',
          operation: 'delete',
          client_updated_at: '2026-05-15T10:05:00.000Z',
          payload: {
            id: 'm-sync-1',
            metric_type: 'weight',
            value: 74.0,
            unit: 'kg',
            recorded_at: '2026-05-15T10:00:00.000Z',
            local_day: '2026-05-15',
            created_at: '2026-05-15T10:00:00.000Z',
            updated_at: '2026-05-15T10:05:00.000Z',
            deleted_at: '2026-05-15T10:05:00.000Z',
            source: 'manual',
            context: {},
          },
        },
      ],
    });

    // 4. Concurrent non-delete edit at 10:10 cannot resurrect a tombstone (Tombstone-Wins)
    const resurrectAttempt = await applySyncPushBatch({
      authenticatedUserId: userA,
      operations: [
        {
          entity_type: 'measurements',
          entity_id: 'm-sync-1',
          operation: 'upsert',
          client_updated_at: '2026-05-15T10:10:00.000Z',
          payload: {
            id: 'm-sync-1',
            metric_type: 'weight',
            value: 73.5,
            unit: 'kg',
            recorded_at: '2026-05-15T10:00:00.000Z',
            local_day: '2026-05-15',
            created_at: '2026-05-15T10:00:00.000Z',
            updated_at: '2026-05-15T10:10:00.000Z',
            source: 'manual',
            context: {},
          },
        },
      ],
    });
    expect(resurrectAttempt.results[0]?.status).toBe('rejected');

    const afterTombstone = await pullSyncChanges({
      authenticatedUserId: userA,
      since: null,
    });
    expect(afterTombstone.changes[0]?.operation).toBe('delete');
    expect(afterTombstone.changes[0]?.payload.deleted_at).toBe(
      '2026-05-15T10:05:00.000Z',
    );
  });

  it('strictly isolates User A records from User B and cascades account deletion', async () => {
    const userA = 'user-isolation-a';
    const userB = 'user-isolation-b';

    await applySyncPushBatch({
      authenticatedUserId: userA,
      operations: [
        {
          entity_type: 'measurements',
          entity_id: 'secret-bp-a',
          operation: 'upsert',
          client_updated_at: '2026-05-15T11:00:00.000Z',
          payload: {
            id: 'secret-bp-a',
            metric_type: 'blood_pressure',
            value: 120,
            unit: 'mmHg',
            secondary_value: 78,
            secondary_unit: 'mmHg',
            tertiary_value: 62,
            tertiary_unit: 'bpm',
            recorded_at: '2026-05-15T11:00:00.000Z',
            local_day: '2026-05-15',
            created_at: '2026-05-15T11:00:00.000Z',
            updated_at: '2026-05-15T11:00:00.000Z',
            source: 'manual',
            context: {},
          },
        },
      ],
    });

    // User B pulls changes -> must see zero records from User A
    const pullB = await pullSyncChanges({
      authenticatedUserId: userB,
      since: null,
    });
    expect(pullB.changes).toHaveLength(0);

    // Mismatched RLS session context throws Postgres RLS policy violation
    await expect(
      pullSyncChanges({
        authenticatedUserId: userA,
        rlsSessionUserId: userB,
        since: null,
      }),
    ).rejects.toThrow(/RLS policy violation/i);

    // User A deletes account -> all User A records are purged
    await deleteAccountCascade(userA);
    const pullAAfterDelete = await pullSyncChanges({
      authenticatedUserId: userA,
      since: null,
    });
    expect(pullAAfterDelete.changes).toHaveLength(0);
  });
});
