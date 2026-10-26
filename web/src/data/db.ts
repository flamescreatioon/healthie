/**
 * Dexie.js IndexedDB store for Healthie Web (`docs/web/03-local-data-web.md`).
 *
 * IndexedDB is the web source of truth for the UI.
 * Versioned from v1 with permanent migration discipline.
 */

import Dexie, { type Table } from 'dexie';
import type {
  HealthGoal,
  HealthProfile,
  Measurement,
  Medication,
  MedicationLog,
  Reminder,
  SyncOutboxEntry,
} from '@/domain';

export interface SyncMetaRow {
  readonly key: string;
  readonly value: string;
  readonly updatedAt: string;
}

export class HealthieLocalDb extends Dexie {
  measurements!: Table<Measurement, string>;
  syncOutbox!: Table<SyncOutboxEntry, string>;
  syncMeta!: Table<SyncMetaRow, string>;
  profiles!: Table<HealthProfile, string>;
  goals!: Table<HealthGoal, string>;
  reminders!: Table<Reminder, string>;
  medications!: Table<Medication, string>;
  medicationLogs!: Table<MedicationLog, string>;

  constructor(dbName = 'healthie_local_db') {
    super(dbName);

    // Schema v1: core measurements, outbox, sync meta, profile, goals, reminders
    this.version(1).stores({
      measurements:
        'id, metricType, recordedAt, localDay, updatedAt, deletedAt, [metricType+recordedAt], [metricType+localDay]',
      syncOutbox: 'entityId, entityType, operation, queuedAt, isProcessing',
      syncMeta: 'key',
      profiles: 'id, updatedAt',
      goals: 'id, metricType, active, updatedAt',
      reminders: 'id, metricType, enabled, updatedAt',
    });

    // Schema v2: adds medications and medicationLogs tables + ensures localDay normalization
    this.version(2)
      .stores({
        measurements:
          'id, metricType, recordedAt, localDay, updatedAt, deletedAt, [metricType+recordedAt], [metricType+localDay]',
        syncOutbox: 'entityId, entityType, operation, queuedAt, isProcessing',
        syncMeta: 'key',
        profiles: 'id, updatedAt',
        goals: 'id, metricType, active, updatedAt',
        reminders: 'id, metricType, enabled, updatedAt',
        medications: 'id, active, updatedAt',
        medicationLogs: 'id, medicationId, scheduledAt, recordedAt',
      })
      .upgrade(async (tx) => {
        await tx
          .table<Measurement, string>('measurements')
          .toCollection()
          .modify((row) => {
            if (!row.localDay && row.recordedAt) {
              const d = new Date(row.recordedAt);
              const year = d.getFullYear();
              const month = String(d.getMonth() + 1).padStart(2, '0');
              const day = String(d.getDate()).padStart(2, '0');
              (row as { localDay: string }).localDay = `${year}-${month}-${day}`;
            }
          });
      });
  }
}

let defaultDbInstance: HealthieLocalDb | null = null;

export function getLocalDb(): HealthieLocalDb {
  if (!defaultDbInstance) {
    defaultDbInstance = new HealthieLocalDb();
  }
  return defaultDbInstance;
}

/**
 * Checks whether IndexedDB is available and writable (detects private-window
 * or storage-pressure degradation explicitly per `docs/web/03-local-data-web.md`).
 */
export async function checkIndexedDbAvailability(
  db: HealthieLocalDb = getLocalDb(),
): Promise<{ available: boolean; reason?: string }> {
  try {
    await db.open();
    return { available: true };
  } catch (err) {
    const message = err instanceof Error ? err.message : 'IndexedDB unavailable';
    return {
      available: false,
      reason:
        'Local browser storage is unavailable (possibly due to private browsing mode or storage quota). Readings in this session may not persist after closing the tab.',
    };
  }
}
