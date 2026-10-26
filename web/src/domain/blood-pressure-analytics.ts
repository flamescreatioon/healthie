/**
 * Blood-pressure analytics for one period
 * (1:1 port of `lib/features/analytics/domain/blood_pressure_analytics.dart`).
 *
 * Every number is derived from stored readings. A day with no reading is a gap,
 * never interpolated or filled with zero.
 */

import {
  ALL_BP_CATEGORIES,
  type BpCategoryWire,
  type BpGuideline,
  defaultBpGuideline,
} from './blood-pressure-guideline';
import { type DateRange, dateRangeDayCount } from './date-range';
import {
  isEveningHour,
  isMorningHour,
  localDaysBetween,
  startOfLocalDay,
  toLocalDayString,
} from './date-utils';
import type { Measurement } from './measurement';
import {
  computeDescriptiveStats,
  type DescriptiveStats,
  type TimedValue,
} from './statistics';
import { analyseTrend, type TrendResult } from './trend';

export interface BpDailyPoint {
  readonly day: Date;
  readonly localDay: string;
  readonly systolic: number | null;
  readonly diastolic: number | null;
  readonly sampleCount: number;
}

export interface BpAverages {
  readonly systolic: number | null;
  readonly diastolic: number | null;
  readonly sampleCount: number;
  readonly hasData: boolean;
}

export const BP_AVERAGES_NONE: BpAverages = {
  systolic: null,
  diastolic: null,
  sampleCount: 0,
  hasData: false,
};

export interface BpPeriodSummary {
  readonly period: DateRange;
  readonly systolic: DescriptiveStats | null;
  readonly diastolic: DescriptiveStats | null;
  readonly latest: Measurement | null;
  /** Logged days only (oldest first). */
  readonly daily: readonly BpDailyPoint[];
  /** Contiguous calendar days across the period with `null` on missing days for gap rendering. */
  readonly contiguousSeries: readonly BpDailyPoint[];
  readonly distribution: Record<BpCategoryWire, number>;
  readonly morning: BpAverages;
  readonly evening: BpAverages;
  readonly loggedDays: number;
  readonly totalDays: number;
  readonly completeness: number;
  readonly readingCount: number;
  readonly systolicTrend: TrendResult;
  readonly diastolicTrend: TrendResult;
  readonly guideline: BpGuideline;
}

export function summariseBloodPressure(params: {
  period: DateRange;
  measurements: readonly Measurement[];
  guideline?: BpGuideline;
}): BpPeriodSummary {
  const guideline = params.guideline ?? defaultBpGuideline;
  const readings = params.measurements
    .filter((m) => m.metricType === 'blood_pressure' && !m.deletedAt)
    .slice()
    .sort((a, b) => new Date(a.recordedAt).getTime() - new Date(b.recordedAt).getTime());

  const systolicValues: number[] = [];
  const diastolicValues: number[] = [];
  const distribution: Record<BpCategoryWire, number> = {
    normal: 0,
    elevated: 0,
    stage_1_hypertension: 0,
    stage_2_hypertension: 0,
    hypertensive_crisis: 0,
  };

  for (const r of readings) {
    systolicValues.push(r.value);
    const dia = r.secondaryValue;
    if (dia === null || dia === undefined) continue;
    diastolicValues.push(dia);
    const cat = guideline.classify({
      systolic: Math.round(r.value),
      diastolic: Math.round(dia),
    });
    distribution[cat] = (distribution[cat] ?? 0) + 1;
  }

  const daily = computeDailyMeans(readings);
  const dailyByKey = new Map(daily.map((d) => [d.localDay, d]));
  const endInclusive = new Date(
    params.period.end.getFullYear(),
    params.period.end.getMonth(),
    params.period.end.getDate() - 1,
    0,
    0,
    0,
    0,
  );
  const allDays = localDaysBetween(params.period.start, endInclusive);
  const contiguousSeries: BpDailyPoint[] = allDays.map((day) => {
    const key = toLocalDayString(day);
    return (
      dailyByKey.get(key) ?? {
        day,
        localDay: key,
        systolic: null,
        diastolic: null,
        sampleCount: 0,
      }
    );
  });

  const morningReadings = readings.filter((m) => isMorningHour(new Date(m.recordedAt)));
  const eveningReadings = readings.filter((m) => isEveningHour(new Date(m.recordedAt)));

  const totalDays = dateRangeDayCount(params.period);
  const loggedDays = daily.length;
  const systolicStats = computeDescriptiveStats(systolicValues);
  const diastolicStats = computeDescriptiveStats(diastolicValues);

  const sysTimed: TimedValue[] = daily
    .filter((d) => d.systolic !== null)
    .map((d) => ({ at: d.day, value: d.systolic! }));
  const diaTimed: TimedValue[] = daily
    .filter((d) => d.diastolic !== null)
    .map((d) => ({ at: d.day, value: d.diastolic! }));

  return {
    period: params.period,
    systolic: systolicStats,
    diastolic: diastolicStats,
    latest: readings.length === 0 ? null : readings[readings.length - 1]!,
    daily,
    contiguousSeries,
    distribution,
    morning: computeBpAverages(morningReadings),
    evening: computeBpAverages(eveningReadings),
    loggedDays,
    totalDays,
    completeness: totalDays === 0 ? 0 : loggedDays / totalDays,
    readingCount: systolicStats?.count ?? 0,
    systolicTrend: analyseTrend(sysTimed, { meaningfulChange: 5 }),
    diastolicTrend: analyseTrend(diaTimed, { meaningfulChange: 5 }),
    guideline,
  };
}

function computeDailyMeans(readings: readonly Measurement[]): BpDailyPoint[] {
  const buckets = new Map<
    string,
    { day: Date; systolics: number[]; diastolics: number[] }
  >();

  for (const r of readings) {
    const instant = new Date(r.recordedAt);
    const day = startOfLocalDay(instant);
    const key = toLocalDayString(day);
    let bucket = buckets.get(key);
    if (!bucket) {
      bucket = { day, systolics: [], diastolics: [] };
      buckets.set(key, bucket);
    }
    bucket.systolics.push(r.value);
    if (r.secondaryValue !== null && r.secondaryValue !== undefined) {
      bucket.diastolics.push(r.secondaryValue);
    }
  }

  return [...buckets.entries()]
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([localDay, b]) => ({
      day: b.day,
      localDay,
      systolic: b.systolics.reduce((acc, v) => acc + v, 0) / b.systolics.length,
      diastolic:
        b.diastolics.length === 0
            ? null
            : b.diastolics.reduce((acc, v) => acc + v, 0) / b.diastolics.length,
      sampleCount: b.systolics.length,
    }));
}

function computeBpAverages(readings: readonly Measurement[]): BpAverages {
  if (readings.length === 0) return BP_AVERAGES_NONE;
  const systolics = readings.map((m) => m.value);
  const diastolics = readings
    .map((m) => m.secondaryValue)
    .filter((v): v is number => v !== null && v !== undefined);

  return {
    systolic: systolics.reduce((a, b) => a + b, 0) / systolics.length,
    diastolic:
      diastolics.length === 0
        ? null
        : diastolics.reduce((a, b) => a + b, 0) / diastolics.length,
    sampleCount: readings.length,
    hasData: true,
  };
}

export function bpCategoryShare(
  summary: BpPeriodSummary,
  category: BpCategoryWire,
): number {
  if (summary.readingCount === 0) return 0;
  return (summary.distribution[category] ?? 0) / summary.readingCount;
}

export { ALL_BP_CATEGORIES };
