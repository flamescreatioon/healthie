/**
 * Core Measurement domain model, wire JSON serializer, and catalog-backed
 * validator (1:1 port of `measurement.dart` & `docs/api-contract.md` §3).
 */

import { toLocalDayString, parseLocalDay } from './date-utils';
import {
  isMetricWireName,
  MetricCatalog,
  type MetricWireName,
} from './metric-catalog';
import {
  contextFromJson,
  contextToJson,
  EMPTY_MEASUREMENT_CONTEXT,
  type MeasurementContext,
} from './reading-context';
import { type UnitSymbol, unitFromSymbol } from './units';

export type MeasurementSourceWire =
  | 'manual'
  | 'health_connect'
  | 'imported'
  | 'derived';

export interface Measurement {
  /** Device-generated UUIDv4. Server never assigns IDs. */
  readonly id: string;
  readonly metricType: MetricWireName;
  /** Primary value in canonical unit. */
  readonly value: number;
  readonly unit: UnitSymbol;
  /** Diastolic pressure (mmHg) or body-fat (%) */
  readonly secondaryValue?: number | null;
  readonly secondaryUnit?: UnitSymbol | null;
  /** Pulse (bpm) or waist circumference (cm) */
  readonly tertiaryValue?: number | null;
  readonly tertiaryUnit?: UnitSymbol | null;
  /** UTC timestamp when measurement occurred (ISO-8601). */
  readonly recordedAt: string;
  /** Denormalized local calendar day `YYYY-MM-DD`. */
  readonly localDay: string;
  /** UTC timestamp when created on device (ISO-8601). */
  readonly createdAt: string;
  /** UTC timestamp when last modified on device (ISO-8601). */
  readonly updatedAt: string;
  readonly source: MeasurementSourceWire;
  readonly isSynced: boolean;
  /** Soft-delete tombstone UTC timestamp (ISO-8601) or null. */
  readonly deletedAt?: string | null;
  readonly context: MeasurementContext;
}

export interface MeasurementWireJson {
  id: string;
  metric_type: MetricWireName;
  value: number;
  unit: string;
  secondary_value?: number | null;
  secondary_unit?: string | null;
  tertiary_value?: number | null;
  tertiary_unit?: string | null;
  recorded_at: string;
  local_day: string;
  created_at: string;
  updated_at: string;
  source: string;
  is_synced?: boolean;
  deleted_at?: string | null;
  context?: Record<string, unknown>;
}

export function isDeleted(measurement: Measurement): boolean {
  return measurement.deletedAt !== null && measurement.deletedAt !== undefined;
}

export function getDiastolic(measurement: Measurement): number | null {
  return measurement.metricType === 'blood_pressure'
    ? (measurement.secondaryValue ?? null)
    : null;
}

export function getPulse(measurement: Measurement): number | null {
  return measurement.metricType === 'blood_pressure'
    ? (measurement.tertiaryValue ?? null)
    : null;
}

export function getBodyFatPercent(measurement: Measurement): number | null {
  return measurement.metricType === 'weight'
    ? (measurement.secondaryValue ?? null)
    : null;
}

export function getWaistCircumference(measurement: Measurement): number | null {
  return measurement.metricType === 'weight'
    ? (measurement.tertiaryValue ?? null)
    : null;
}

export function measurementToJson(m: Measurement): MeasurementWireJson {
  const json: MeasurementWireJson = {
    id: m.id,
    metric_type: m.metricType,
    value: m.value,
    unit: m.unit,
    recorded_at: new Date(m.recordedAt).toISOString(),
    local_day: m.localDay,
    created_at: new Date(m.createdAt).toISOString(),
    updated_at: new Date(m.updatedAt).toISOString(),
    source: m.source,
    is_synced: m.isSynced,
    deleted_at: m.deletedAt ? new Date(m.deletedAt).toISOString() : null,
    context: contextToJson(m.context),
  };

  if (m.secondaryValue !== undefined && m.secondaryValue !== null) {
    json.secondary_value = m.secondaryValue;
  }
  if (m.secondaryUnit !== undefined && m.secondaryUnit !== null) {
    json.secondary_unit = m.secondaryUnit;
  }
  if (m.tertiaryValue !== undefined && m.tertiaryValue !== null) {
    json.tertiary_value = m.tertiaryValue;
  }
  if (m.tertiaryUnit !== undefined && m.tertiaryUnit !== null) {
    json.tertiary_unit = m.tertiaryUnit;
  }
  return json;
}

export function measurementFromJson(raw: Record<string, unknown>): Measurement {
  const metricRaw = String(raw.metric_type ?? '');
  if (!isMetricWireName(metricRaw)) {
    throw new Error(`Unsupported metric_type: ${metricRaw}`);
  }
  const recordedDate = new Date(String(raw.recorded_at));
  const localDayStr =
    typeof raw.local_day === 'string' && raw.local_day.length >= 10
      ? toLocalDayString(parseLocalDay(raw.local_day))
      : toLocalDayString(recordedDate);

  const unitSpec = unitFromSymbol(String(raw.unit ?? ''));
  const secondaryUnitSpec =
    typeof raw.secondary_unit === 'string' ? unitFromSymbol(raw.secondary_unit) : null;
  const tertiaryUnitSpec =
    typeof raw.tertiary_unit === 'string' ? unitFromSymbol(raw.tertiary_unit) : null;

  const sourceRaw = String(raw.source ?? 'manual');
  const source: MeasurementSourceWire =
    sourceRaw === 'health_connect' ||
    sourceRaw === 'imported' ||
    sourceRaw === 'derived'
      ? sourceRaw
      : 'manual';

  return {
    id: String(raw.id),
    metricType: metricRaw,
    value: Number(raw.value),
    unit: unitSpec.symbol,
    secondaryValue:
      raw.secondary_value !== undefined && raw.secondary_value !== null
        ? Number(raw.secondary_value)
        : null,
    secondaryUnit: secondaryUnitSpec ? secondaryUnitSpec.symbol : null,
    tertiaryValue:
      raw.tertiary_value !== undefined && raw.tertiary_value !== null
        ? Number(raw.tertiary_value)
        : null,
    tertiaryUnit: tertiaryUnitSpec ? tertiaryUnitSpec.symbol : null,
    recordedAt: recordedDate.toISOString(),
    localDay: localDayStr,
    createdAt: new Date(String(raw.created_at ?? raw.recorded_at)).toISOString(),
    updatedAt: new Date(String(raw.updated_at ?? raw.recorded_at)).toISOString(),
    source,
    isSynced: Boolean(raw.is_synced ?? false),
    deletedAt:
      typeof raw.deleted_at === 'string' && raw.deleted_at.length > 0
        ? new Date(raw.deleted_at).toISOString()
        : null,
    context:
      raw.context && typeof raw.context === 'object'
        ? contextFromJson(raw.context)
        : EMPTY_MEASUREMENT_CONTEXT,
  };
}

export interface MeasurementValidationErrors {
  value?: string;
  secondaryValue?: string;
  tertiaryValue?: string;
  recordedAt?: string;
}

/**
 * Validates canonical measurement values against `MetricCatalog` bounds.
 * Never silently clamps or rounds; returns specific human-readable field errors.
 */
export function validateCanonicalMeasurement(params: {
  metricType: MetricWireName;
  value: number | null | undefined;
  secondaryValue?: number | null | undefined;
  tertiaryValue?: number | null | undefined;
  recordedAt?: Date | string | null | undefined;
  now?: Date;
}): { valid: boolean; errors: MeasurementValidationErrors } {
  const spec = MetricCatalog[params.metricType];
  const errors: MeasurementValidationErrors = {};

  if (
    params.value === null ||
    params.value === undefined ||
    !Number.isFinite(params.value) ||
    params.value < spec.min ||
    params.value > spec.max
  ) {
    if (params.metricType === 'blood_pressure') {
      errors.value = `Enter a systolic value between ${spec.min} and ${spec.max} ${spec.canonicalUnit.symbol}`;
    } else if (params.metricType === 'weight') {
      errors.value = `Enter a weight between ${spec.min} and ${spec.max} ${spec.canonicalUnit.symbol}`;
    } else {
      errors.value = `Enter a ${spec.displayName.toLowerCase()} between ${spec.min} and ${spec.max} ${spec.canonicalUnit.symbol}`;
    }
  }

  if (spec.secondary) {
    const sec = params.secondaryValue;
    if (!spec.secondary.optional && (sec === null || sec === undefined)) {
      errors.secondaryValue = `Enter a ${spec.secondary.label.toLowerCase()} value between ${spec.secondary.min} and ${spec.secondary.max} ${spec.secondary.unit.symbol}`;
    } else if (
      sec !== null &&
      sec !== undefined &&
      (!Number.isFinite(sec) || sec < spec.secondary.min || sec > spec.secondary.max)
    ) {
      errors.secondaryValue = `Enter a ${spec.secondary.label.toLowerCase()} value between ${spec.secondary.min} and ${spec.secondary.max} ${spec.secondary.unit.symbol}`;
    } else if (
      params.metricType === 'blood_pressure' &&
      !errors.value &&
      params.value !== null &&
      params.value !== undefined &&
      sec !== null &&
      sec !== undefined &&
      params.value <= sec
    ) {
      errors.value = 'Systolic must be greater than diastolic';
    }
  }

  if (spec.tertiary) {
    const tert = params.tertiaryValue;
    if (
      tert !== null &&
      tert !== undefined &&
      (!Number.isFinite(tert) || tert < spec.tertiary.min || tert > spec.tertiary.max)
    ) {
      const label =
        params.metricType === 'blood_pressure'
          ? 'pulse'
          : spec.tertiary.label.toLowerCase();
      errors.tertiaryValue = `Enter a ${label} between ${spec.tertiary.min} and ${spec.tertiary.max} ${spec.tertiary.unit.symbol}`;
    }
  }

  if (params.recordedAt) {
    const recordedDate =
      params.recordedAt instanceof Date
        ? params.recordedAt
        : new Date(params.recordedAt);
    const referenceNow = params.now ?? new Date();
    if (
      Number.isNaN(recordedDate.getTime()) ||
      recordedDate.getTime() > referenceNow.getTime() + 5 * 60 * 1000
    ) {
      errors.recordedAt = 'Recorded time cannot be in the future';
    }
  }

  return {
    valid: Object.keys(errors).length === 0,
    errors,
  };
}
