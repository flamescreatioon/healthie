/**
 * User HealthProfile, HealthGoal, Reminder, and Medication domain types
 * (1:1 port of `health_profile.dart`, `reminder.dart`, and `medication.dart`).
 */

import type { MetricWireName } from './metric-catalog';
import type { UnitSymbol } from './units';

export type WeightGoalKindWire = 'none' | 'maintain' | 'lose' | 'gain';

export interface HealthProfile {
  readonly id: string;
  readonly displayName?: string | null;
  readonly dateOfBirth?: string | null;
  readonly sex?: string | null;
  readonly heightCm?: number | null;
  readonly preferredMassUnit: 'kg' | 'lb';
  readonly preferredLengthUnit: 'cm' | 'in';
  readonly preferredTemperatureUnit: '°C' | '°F';
  readonly timeZone?: string | null;
  readonly weightGoalKind: WeightGoalKindWire;
  readonly targetSystolic?: number | null;
  readonly targetDiastolic?: number | null;
  readonly targetWeightKg?: number | null;
  readonly updatedAt: string;
}

export const DEFAULT_HEALTH_PROFILE: HealthProfile = {
  id: 'me',
  displayName: null,
  preferredMassUnit: 'kg',
  preferredLengthUnit: 'cm',
  preferredTemperatureUnit: '°C',
  weightGoalKind: 'none',
  targetSystolic: null,
  targetDiastolic: null,
  targetWeightKg: null,
  updatedAt: '2026-01-01T00:00:00.000Z',
};

export interface HealthGoal {
  readonly id: string;
  readonly metricType: MetricWireName;
  readonly targetValue: number;
  readonly unit: UnitSymbol;
  readonly startValue?: number | null;
  readonly targetDate?: string | null;
  readonly active: boolean;
  readonly updatedAt: string;
}

export type ReminderKindWire =
  | 'morning_blood_pressure'
  | 'evening_blood_pressure'
  | 'weight'
  | 'custom';

export interface Reminder {
  readonly id: string;
  readonly kind: ReminderKindWire;
  readonly metricType: MetricWireName;
  readonly title: string;
  readonly hour: number;
  readonly minute: number;
  readonly enabled: boolean;
  readonly updatedAt: string;
}

export type MedicationLogStatusWire = 'taken' | 'skipped' | 'missed';

export interface Medication {
  readonly id: string;
  readonly name: string;
  readonly dosageInstructions: string;
  readonly schedule: string;
  readonly startDate: string;
  readonly endDate?: string | null;
  readonly active: boolean;
  readonly updatedAt: string;
}

export interface MedicationLog {
  readonly id: string;
  readonly medicationId: string;
  readonly scheduledAt: string;
  readonly status: MedicationLogStatusWire;
  readonly recordedAt: string;
  readonly notes?: string | null;
}
