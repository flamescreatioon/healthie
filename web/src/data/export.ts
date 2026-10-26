/**
 * Offline-capable JSON + CSV export with schema version
 * (`docs/web/08-privacy-compliance.md`).
 *
 * Generated 100% client-side from IndexedDB. Round-trips cleanly with
 * `measurementFromJson`.
 */

import {
  type HealthGoal,
  type HealthProfile,
  type Measurement,
  measurementFromJson,
  measurementToJson,
  type MeasurementWireJson,
} from '@/domain';

export const EXPORT_SCHEMA_VERSION = 1;

export interface HealthieExportBundle {
  readonly schema_version: number;
  readonly exported_at: string;
  readonly app: 'healthie-web';
  readonly profile?: HealthProfile;
  readonly goals?: readonly HealthGoal[];
  readonly measurements: readonly MeasurementWireJson[];
}

export function buildJsonExport(params: {
  measurements: readonly Measurement[];
  profile?: HealthProfile;
  goals?: readonly HealthGoal[];
  exportedAtIso: string;
}): string {
  const activeMeasurements = params.measurements.filter((m) => !m.deletedAt);
  const bundle: HealthieExportBundle = {
    schema_version: EXPORT_SCHEMA_VERSION,
    exported_at: params.exportedAtIso,
    app: 'healthie-web',
    ...(params.profile ? { profile: params.profile } : {}),
    ...(params.goals ? { goals: params.goals } : {}),
    measurements: activeMeasurements.map(measurementToJson),
  };
  return JSON.stringify(bundle, null, 2);
}

export function parseJsonExport(rawJson: string): {
  schemaVersion: number;
  measurements: Measurement[];
} {
  const parsed = JSON.parse(rawJson) as Record<string, unknown>;
  const schemaVersion = Number(parsed.schema_version ?? 1);
  if (!Array.isArray(parsed.measurements)) {
    throw new Error('Invalid export bundle: missing measurements array');
  }
  const measurements = parsed.measurements.map((item) =>
    measurementFromJson(item as Record<string, unknown>),
  );
  return { schemaVersion, measurements };
}

export function buildCsvExport(measurements: readonly Measurement[]): string {
  const header =
    'id,metric_type,value,unit,secondary_value,tertiary_value,recorded_at,local_day,posture,arm,circumstances,notes';
  const rows = measurements
    .filter((m) => !m.deletedAt)
    .map((m) => {
      const circumstances = m.context.circumstances?.join(';') ?? '';
      return [
        m.id,
        m.metricType,
        m.value,
        m.unit,
        m.secondaryValue ?? '',
        m.tertiaryValue ?? '',
        new Date(m.recordedAt).toISOString(),
        m.localDay,
        m.context.posture ?? '',
        m.context.arm ?? '',
        escapeCsvCell(circumstances),
        escapeCsvCell(m.context.notes ?? ''),
      ].join(',');
    });

  return [header, ...rows].join('\n') + '\n';
}

function escapeCsvCell(value: string): string {
  return `"${value.replace(/"/g, '""')}"`;
}
