/**
 * Closed catalogue of metrics Healthie tracks (1:1 port of `metric_type.dart`).
 *
 * `wireName` is the permanent contract written to IndexedDB, sync payloads,
 * and the Neon Postgres database. Never rename an existing `wireName`.
 */

import { Units, type UnitSpec } from './units';

export type MetricWireName =
  | 'blood_pressure'
  | 'weight'
  | 'heart_rate'
  | 'spo2'
  | 'body_temperature'
  | 'blood_glucose';

export const METRIC_WIRE_NAMES: readonly MetricWireName[] = [
  'blood_pressure',
  'weight',
  'heart_rate',
  'spo2',
  'body_temperature',
  'blood_glucose',
] as const;

export function isMetricWireName(value: string): value is MetricWireName {
  return (METRIC_WIRE_NAMES as readonly string[]).includes(value);
}

export interface MetricComponent {
  readonly label: string;
  readonly unit: UnitSpec;
  readonly min: number;
  readonly max: number;
  readonly precision: number;
  readonly optional: boolean;
}

export interface MetricSpec {
  readonly wireName: MetricWireName;
  readonly displayName: string;
  readonly shortName: string;
  readonly description: string;
  readonly canonicalUnit: UnitSpec;
  readonly precision: number;
  readonly min: number;
  readonly max: number;
  readonly step: number;
  readonly entryUnits: readonly UnitSpec[];
  readonly secondary?: MetricComponent;
  readonly tertiary?: MetricComponent;
}

export const MetricCatalog: Record<MetricWireName, MetricSpec> = {
  blood_pressure: {
    wireName: 'blood_pressure',
    displayName: 'Blood Pressure',
    shortName: 'BP',
    description: 'Systolic, diastolic, and an optional pulse, with posture and circumstance.',
    canonicalUnit: Units.millimetreOfMercury,
    precision: 0,
    min: 50,
    max: 260,
    step: 1,
    entryUnits: [Units.millimetreOfMercury],
    secondary: {
      label: 'Diastolic',
      unit: Units.millimetreOfMercury,
      min: 30,
      max: 160,
      precision: 0,
      optional: false,
    },
    tertiary: {
      label: 'Resting Heart Rate',
      unit: Units.beatsPerMinute,
      min: 20,
      max: 250,
      precision: 0,
      optional: true,
    },
  },
  weight: {
    wireName: 'weight',
    displayName: 'Body Weight',
    shortName: 'Weight',
    description: 'Weight, with optional body fat and waist circumference.',
    canonicalUnit: Units.kilogram,
    precision: 1,
    min: 20,
    max: 400,
    step: 0.1,
    entryUnits: [Units.kilogram, Units.pound],
    secondary: {
      label: 'Body Fat',
      unit: Units.percent,
      min: 2,
      max: 70,
      precision: 1,
      optional: true,
    },
    tertiary: {
      label: 'Waist',
      unit: Units.centimetre,
      min: 30,
      max: 200,
      precision: 1,
      optional: true,
    },
  },
  heart_rate: {
    wireName: 'heart_rate',
    displayName: 'Heart Rate',
    shortName: 'Heart Rate',
    description: 'Pulse in beats per minute, with context and notes.',
    canonicalUnit: Units.beatsPerMinute,
    precision: 0,
    min: 20,
    max: 250,
    step: 1,
    entryUnits: [Units.beatsPerMinute],
  },
  spo2: {
    wireName: 'spo2',
    displayName: 'Blood Oxygen',
    shortName: 'SpO₂',
    description: 'SpO₂ saturation as a percentage.',
    canonicalUnit: Units.percent,
    precision: 0,
    min: 50,
    max: 100,
    step: 1,
    entryUnits: [Units.percent],
  },
  body_temperature: {
    wireName: 'body_temperature',
    displayName: 'Body Temperature',
    shortName: 'Temperature',
    description: 'Temperature in Celsius or Fahrenheit.',
    canonicalUnit: Units.celsius,
    precision: 1,
    min: 30,
    max: 45,
    step: 0.1,
    entryUnits: [Units.celsius, Units.fahrenheit],
  },
  blood_glucose: {
    wireName: 'blood_glucose',
    displayName: 'Blood Glucose',
    shortName: 'Glucose',
    description: 'Concentration with fasting or post-meal context.',
    canonicalUnit: Units.milligramPerDecilitre,
    precision: 0,
    min: 20,
    max: 600,
    step: 1,
    entryUnits: [Units.milligramPerDecilitre, Units.millimolePerLitre],
  },
} as const;

export const ALL_METRIC_SPECS: readonly MetricSpec[] = METRIC_WIRE_NAMES.map(
  (name) => MetricCatalog[name],
);

export function specForMetric(wireName: MetricWireName): MetricSpec {
  return MetricCatalog[wireName];
}
