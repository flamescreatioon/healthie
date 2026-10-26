/**
 * Dexie-backed Repository implementations (`docs/web/03-local-data-web.md`).
 *
 * Critical invariant: Every measurement write (`save`, `softDelete`, `restore`)
 * commits the row and enqueues/updates its `syncOutbox` entry inside a SINGLE
 * Dexie transaction (`db.transaction('rw', db.measurements, db.syncOutbox, ...)`).
 * A write that lands without its outbox row is impossible.
 */

import {
  dateRangeContains,
  type DateRange,
  DEFAULT_HEALTH_PROFILE,
  type HealthGoal,
  type HealthProfile,
  type Measurement,
  type MeasurementRepository,
  measurementToJson,
  type Medication,
  type MedicationLog,
  type MedicationRepository,
  type MetricWireName,
  type ProfileRepository,
  type Reminder,
  type ReminderRepository,
  type SyncOutboxEntry,
} from '@/domain';
import { getLocalDb, type HealthieLocalDb } from './db';

export class DexieMeasurementRepository implements MeasurementRepository {
  private readonly db: HealthieLocalDb;

  constructor(db: HealthieLocalDb = getLocalDb()) {
    this.db = db;
  }

  async list(params?: {
    metricType?: MetricWireName;
    range?: DateRange;
    includeDeleted?: boolean;
  }): Promise<Measurement[]> {
    const all = params?.metricType
      ? await this.db.measurements.where('metricType').equals(params.metricType).toArray()
      : await this.db.measurements.toArray();

    return all
      .filter((m) => {
        if (!params?.includeDeleted && m.deletedAt) return false;
        if (params?.range && !dateRangeContains(params.range, new Date(m.recordedAt))) {
          return false;
        }
        return true;
      })
      .sort(
        (a, b) => new Date(b.recordedAt).getTime() - new Date(a.recordedAt).getTime(),
      );
  }

  async getById(id: string): Promise<Measurement | null> {
    const row = await this.db.measurements.get(id);
    if (!row || row.deletedAt) return null;
    return row;
  }

  async latestOf(metricType: MetricWireName): Promise<Measurement | null> {
    const rows = await this.list({ metricType });
    return rows[0] ?? null;
  }

  async save(measurement: Measurement): Promise<void> {
    const normalized: Measurement = {
      ...measurement,
      isSynced: false,
      deletedAt: null,
    };
    const outboxRow: SyncOutboxEntry = {
      entityId: normalized.id,
      entityType: 'measurements',
      operation: 'upsert',
      payload: JSON.stringify(measurementToJson(normalized)),
      clientUpdatedAt: normalized.updatedAt,
      queuedAt: normalized.updatedAt,
      attempts: 0,
      lastError: null,
      isProcessing: false,
    };

    await this.db.transaction(
      'rw',
      this.db.measurements,
      this.db.syncOutbox,
      async () => {
        await this.db.measurements.put(normalized);
        await this.db.syncOutbox.put(outboxRow);
      },
    );
  }

  async softDelete(id: string, deletedAtIso: string): Promise<void> {
    await this.db.transaction(
      'rw',
      this.db.measurements,
      this.db.syncOutbox,
      async () => {
        const existing = await this.db.measurements.get(id);
        if (!existing) return;
        const tombstone: Measurement = {
          ...existing,
          deletedAt: deletedAtIso,
          updatedAt: deletedAtIso,
          isSynced: false,
        };
        const outboxRow: SyncOutboxEntry = {
          entityId: id,
          entityType: 'measurements',
          operation: 'delete',
          payload: JSON.stringify(measurementToJson(tombstone)),
          clientUpdatedAt: deletedAtIso,
          queuedAt: deletedAtIso,
          attempts: 0,
          lastError: null,
          isProcessing: false,
        };
        await this.db.measurements.put(tombstone);
        // Replaces any pending upsert in syncOutbox for this entityId (tombstone-wins in outbox)
        await this.db.syncOutbox.put(outboxRow);
      },
    );
  }

  async restore(id: string, updatedAtIso: string): Promise<void> {
    await this.db.transaction(
      'rw',
      this.db.measurements,
      this.db.syncOutbox,
      async () => {
        const existing = await this.db.measurements.get(id);
        if (!existing) return;
        const restored: Measurement = {
          ...existing,
          deletedAt: null,
          updatedAt: updatedAtIso,
          isSynced: false,
        };
        const outboxRow: SyncOutboxEntry = {
          entityId: id,
          entityType: 'measurements',
          operation: 'upsert',
          payload: JSON.stringify(measurementToJson(restored)),
          clientUpdatedAt: updatedAtIso,
          queuedAt: updatedAtIso,
          attempts: 0,
          lastError: null,
          isProcessing: false,
        };
        await this.db.measurements.put(restored);
        await this.db.syncOutbox.put(outboxRow);
      },
    );
  }

  async getOutbox(): Promise<SyncOutboxEntry[]> {
    return this.db.syncOutbox.orderBy('queuedAt').toArray();
  }
}

export class DexieProfileRepository implements ProfileRepository {
  private readonly db: HealthieLocalDb;

  constructor(db: HealthieLocalDb = getLocalDb()) {
    this.db = db;
  }

  async getProfile(): Promise<HealthProfile> {
    const row = await this.db.profiles.get('me');
    return row ?? DEFAULT_HEALTH_PROFILE;
  }

  async saveProfile(profile: HealthProfile): Promise<void> {
    const normalized: HealthProfile = { ...profile, id: 'me' };
    await this.db.transaction('rw', this.db.profiles, this.db.syncOutbox, async () => {
      await this.db.profiles.put(normalized);
      await this.db.syncOutbox.put({
        entityId: 'me',
        entityType: 'profile',
        operation: 'upsert',
        payload: JSON.stringify(normalized),
        clientUpdatedAt: normalized.updatedAt,
        queuedAt: normalized.updatedAt,
        attempts: 0,
        lastError: null,
        isProcessing: false,
      });
    });
  }

  async listGoals(): Promise<HealthGoal[]> {
    return this.db.goals.toArray();
  }

  async saveGoal(goal: HealthGoal): Promise<void> {
    await this.db.transaction('rw', this.db.goals, this.db.syncOutbox, async () => {
      await this.db.goals.put(goal);
      await this.db.syncOutbox.put({
        entityId: goal.id,
        entityType: 'goals',
        operation: 'upsert',
        payload: JSON.stringify(goal),
        clientUpdatedAt: goal.updatedAt,
        queuedAt: goal.updatedAt,
        attempts: 0,
        lastError: null,
        isProcessing: false,
      });
    });
  }

  async deleteGoal(id: string): Promise<void> {
    const nowIso = new Date().toISOString();
    await this.db.transaction('rw', this.db.goals, this.db.syncOutbox, async () => {
      await this.db.goals.delete(id);
      await this.db.syncOutbox.put({
        entityId: id,
        entityType: 'goals',
        operation: 'delete',
        payload: JSON.stringify({ id, deleted_at: nowIso }),
        clientUpdatedAt: nowIso,
        queuedAt: nowIso,
        attempts: 0,
        lastError: null,
        isProcessing: false,
      });
    });
  }
}

export class DexieReminderRepository implements ReminderRepository {
  private readonly db: HealthieLocalDb;

  constructor(db: HealthieLocalDb = getLocalDb()) {
    this.db = db;
  }

  async listReminders(): Promise<Reminder[]> {
    const all = await this.db.reminders.toArray();
    return all.sort((a, b) => a.hour * 60 + a.minute - (b.hour * 60 + b.minute));
  }

  async saveReminder(reminder: Reminder): Promise<void> {
    await this.db.reminders.put(reminder);
  }

  async deleteReminder(id: string): Promise<void> {
    await this.db.reminders.delete(id);
  }

  async seedDefaults(nowIso: string): Promise<Reminder[]> {
    const defaults: Reminder[] = [
      {
        id: 'rem-morning-bp',
        kind: 'morning_blood_pressure',
        metricType: 'blood_pressure',
        title: 'Morning BP check',
        hour: 8,
        minute: 0,
        enabled: true,
        updatedAt: nowIso,
      },
      {
        id: 'rem-evening-bp',
        kind: 'evening_blood_pressure',
        metricType: 'blood_pressure',
        title: 'Evening BP check',
        hour: 20,
        minute: 0,
        enabled: true,
        updatedAt: nowIso,
      },
      {
        id: 'rem-morning-weight',
        kind: 'weight',
        metricType: 'weight',
        title: 'Morning weigh-in',
        hour: 7,
        minute: 30,
        enabled: true,
        updatedAt: nowIso,
      },
    ];
    await this.db.reminders.bulkPut(defaults);
    return this.listReminders();
  }
}

export class DexieMedicationRepository implements MedicationRepository {
  private readonly db: HealthieLocalDb;

  constructor(db: HealthieLocalDb = getLocalDb()) {
    this.db = db;
  }

  async listMedications(): Promise<Medication[]> {
    return this.db.medications.toArray();
  }

  async saveMedication(medication: Medication): Promise<void> {
    await this.db.medications.put(medication);
  }

  async deleteMedication(id: string): Promise<void> {
    await this.db.medications.delete(id);
  }

  async listLogs(medicationId?: string): Promise<MedicationLog[]> {
    if (medicationId) {
      return this.db.medicationLogs.where('medicationId').equals(medicationId).toArray();
    }
    return this.db.medicationLogs.toArray();
  }

  async saveLog(log: MedicationLog): Promise<void> {
    await this.db.medicationLogs.put(log);
  }
}
