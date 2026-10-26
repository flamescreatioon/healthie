/**
 * Platform-blind Repository interfaces and in-memory Fake implementations
 * (`docs/web/02-domain-architecture.md`).
 *
 * UI components depend on these interfaces, never directly on Dexie or fetch,
 * allowing components and tests to boot with fake repositories and zero browser
 * storage or network dependency.
 */

import type { DateRange } from './date-range';
import { dateRangeContains } from './date-range';
import type { Measurement } from './measurement';
import type { MetricWireName } from './metric-catalog';
import {
  DEFAULT_HEALTH_PROFILE,
  type HealthGoal,
  type HealthProfile,
  type Medication,
  type MedicationLog,
  type Reminder,
} from './profile';

export type OutboxOperation = 'upsert' | 'delete';

export interface SyncOutboxEntry {
  readonly entityId: string;
  readonly entityType: 'measurements' | 'profile' | 'goals' | 'reminders';
  readonly operation: OutboxOperation;
  readonly payload: string;
  readonly clientUpdatedAt: string;
  readonly queuedAt: string;
  readonly attempts: number;
  readonly lastError?: string | null;
  readonly isProcessing: boolean;
}

export interface MeasurementRepository {
  list(params?: {
    metricType?: MetricWireName;
    range?: DateRange;
    includeDeleted?: boolean;
  }): Promise<Measurement[]>;
  getById(id: string): Promise<Measurement | null>;
  latestOf(metricType: MetricWireName): Promise<Measurement | null>;
  save(measurement: Measurement): Promise<void>;
  softDelete(id: string, deletedAtIso: string): Promise<void>;
  restore(id: string, updatedAtIso: string): Promise<void>;
  getOutbox(): Promise<SyncOutboxEntry[]>;
}

export interface ProfileRepository {
  getProfile(): Promise<HealthProfile>;
  saveProfile(profile: HealthProfile): Promise<void>;
  listGoals(): Promise<HealthGoal[]>;
  saveGoal(goal: HealthGoal): Promise<void>;
  deleteGoal(id: string): Promise<void>;
}

export interface ReminderRepository {
  listReminders(): Promise<Reminder[]>;
  saveReminder(reminder: Reminder): Promise<void>;
  deleteReminder(id: string): Promise<void>;
  seedDefaults(nowIso: string): Promise<Reminder[]>;
}

export interface MedicationRepository {
  listMedications(): Promise<Medication[]>;
  saveMedication(medication: Medication): Promise<void>;
  deleteMedication(id: string): Promise<void>;
  listLogs(medicationId?: string): Promise<MedicationLog[]>;
  saveLog(log: MedicationLog): Promise<void>;
}

/**
 * In-memory FakeMeasurementRepository with full outbox compaction semantics
 * for unit and component tests.
 */
export class FakeMeasurementRepository implements MeasurementRepository {
  private readonly store = new Map<string, Measurement>();
  private readonly outbox = new Map<string, SyncOutboxEntry>();

  constructor(initial: readonly Measurement[] = []) {
    for (const m of initial) {
      this.store.set(m.id, m);
    }
  }

  async list(params?: {
    metricType?: MetricWireName;
    range?: DateRange;
    includeDeleted?: boolean;
  }): Promise<Measurement[]> {
    const items = [...this.store.values()].filter((m) => {
      if (!params?.includeDeleted && m.deletedAt) return false;
      if (params?.metricType && m.metricType !== params.metricType) return false;
      if (params?.range && !dateRangeContains(params.range, new Date(m.recordedAt))) {
        return false;
      }
      return true;
    });
    return items.sort(
      (a, b) => new Date(b.recordedAt).getTime() - new Date(a.recordedAt).getTime(),
    );
  }

  async getById(id: string): Promise<Measurement | null> {
    const found = this.store.get(id);
    if (!found || found.deletedAt) return null;
    return found;
  }

  async latestOf(metricType: MetricWireName): Promise<Measurement | null> {
    const list = await this.list({ metricType });
    return list[0] ?? null;
  }

  async save(measurement: Measurement): Promise<void> {
    const saved: Measurement = { ...measurement, isSynced: false, deletedAt: null };
    this.store.set(saved.id, saved);
    this.outbox.set(saved.id, {
      entityId: saved.id,
      entityType: 'measurements',
      operation: 'upsert',
      payload: JSON.stringify(saved),
      clientUpdatedAt: saved.updatedAt,
      queuedAt: saved.updatedAt,
      attempts: 0,
      lastError: null,
      isProcessing: false,
    });
  }

  async softDelete(id: string, deletedAtIso: string): Promise<void> {
    const existing = this.store.get(id);
    if (!existing) return;
    const tombstone: Measurement = {
      ...existing,
      deletedAt: deletedAtIso,
      updatedAt: deletedAtIso,
      isSynced: false,
    };
    this.store.set(id, tombstone);
    // Outbox compaction rule: delete replaces any pending upsert for the same entityId
    this.outbox.set(id, {
      entityId: id,
      entityType: 'measurements',
      operation: 'delete',
      payload: JSON.stringify(tombstone),
      clientUpdatedAt: deletedAtIso,
      queuedAt: deletedAtIso,
      attempts: 0,
      lastError: null,
      isProcessing: false,
    });
  }

  async restore(id: string, updatedAtIso: string): Promise<void> {
    const existing = this.store.get(id);
    if (!existing) return;
    const restored: Measurement = {
      ...existing,
      deletedAt: null,
      updatedAt: updatedAtIso,
      isSynced: false,
    };
    this.store.set(id, restored);
    this.outbox.set(id, {
      entityId: id,
      entityType: 'measurements',
      operation: 'upsert',
      payload: JSON.stringify(restored),
      clientUpdatedAt: updatedAtIso,
      queuedAt: updatedAtIso,
      attempts: 0,
      lastError: null,
      isProcessing: false,
    });
  }

  async getOutbox(): Promise<SyncOutboxEntry[]> {
    return [...this.outbox.values()];
  }
}

export class FakeProfileRepository implements ProfileRepository {
  private profile: HealthProfile = DEFAULT_HEALTH_PROFILE;
  private readonly goals = new Map<string, HealthGoal>();

  async getProfile(): Promise<HealthProfile> {
    return this.profile;
  }

  async saveProfile(profile: HealthProfile): Promise<void> {
    this.profile = profile;
  }

  async listGoals(): Promise<HealthGoal[]> {
    return [...this.goals.values()];
  }

  async saveGoal(goal: HealthGoal): Promise<void> {
    this.goals.set(goal.id, goal);
  }

  async deleteGoal(id: string): Promise<void> {
    this.goals.delete(id);
  }
}

export class FakeReminderRepository implements ReminderRepository {
  private readonly reminders = new Map<string, Reminder>();

  async listReminders(): Promise<Reminder[]> {
    return [...this.reminders.values()].sort(
      (a, b) => a.hour * 60 + a.minute - (b.hour * 60 + b.minute),
    );
  }

  async saveReminder(reminder: Reminder): Promise<void> {
    this.reminders.set(reminder.id, reminder);
  }

  async deleteReminder(id: string): Promise<void> {
    this.reminders.delete(id);
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
    for (const r of defaults) {
      this.reminders.set(r.id, r);
    }
    return this.listReminders();
  }
}
