/**
 * Weight analytics for one period
 * (1:1 port of `lib/features/analytics/domain/weight_analytics.dart`).
 */

import { type DateRange, dateRangeDayCount } from './date-range';
import { localDaysBetween, startOfLocalDay, toLocalDayString } from './date-utils';
import { getBodyFatPercent, type Measurement } from './measurement';
import {
  type Change,
  changeBetween,
  computeDescriptiveStats,
  type DescriptiveStats,
  movingAverage,
  type TimedValue,
} from './statistics';
import { analyseTrend, type TrendResult } from './trend';

export interface WeightDailyPoint {
  readonly day: Date;
  readonly localDay: string;
  readonly weight: number | null;
  readonly smoothing: number | null;
  readonly sampleCount: number;
}

export interface GoalProgress {
  readonly target: number;
  readonly current: number;
  readonly start: number;
  readonly percentAchieved: number;
  readonly remaining: number | null;
  readonly hasPassedTarget: boolean;
}

export interface WeightPeriodSummary {
  readonly period: DateRange;
  readonly stats: DescriptiveStats | null;
  readonly daily: readonly WeightDailyPoint[];
  readonly contiguousSeries: readonly WeightDailyPoint[];
  readonly latest: Measurement | null;
  readonly startingWeight: number | null;
  readonly baseline: number | null;
  readonly changeFromPrevious: Change | null;
  readonly trend: TrendResult;
  readonly loggedDays: number;
  readonly totalDays: number;
  readonly completeness: number;
  readonly weeklyPace: number | null;
  readonly bodyFatLatest: number | null;
  readonly bodyFatChange: Change | null;
}

export function summariseWeight(params: {
  period: DateRange;
  measurements: readonly Measurement[];
  previousPeriodMeasurements?: readonly Measurement[];
  smoothingWindow?: number;
}): WeightPeriodSummary {
  const smoothingWindow = params.smoothingWindow ?? 7;
  const previousMeasurements = params.previousPeriodMeasurements ?? [];

  const readings = params.measurements
    .filter((m) => m.metricType === 'weight' && !m.deletedAt)
    .slice()
    .sort((a, b) => new Date(a.recordedAt).getTime() - new Date(b.recordedAt).getTime());

  const values = readings.map((m) => m.value);
  const stats = computeDescriptiveStats(values);
  const daily = buildDailyWeightPoints(readings, smoothingWindow);

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
  const contiguousRaw = allDays.map((day) => {
    const key = toLocalDayString(day);
    return dailyByKey.get(key)?.weight ?? null;
  });
  const contiguousSmoothed = movingAverage(contiguousRaw, Math.min(smoothingWindow, 3));
  const contiguousSeries: WeightDailyPoint[] = allDays.map((day, idx) => {
    const key = toLocalDayString(day);
    const existing = dailyByKey.get(key);
    return {
      day,
      localDay: key,
      weight: existing?.weight ?? null,
      smoothing: existing?.smoothing ?? contiguousSmoothed[idx] ?? null,
      sampleCount: existing?.sampleCount ?? 0,
    };
  });

  const previousValues = previousMeasurements
    .filter((m) => m.metricType === 'weight' && !m.deletedAt)
    .map((m) => m.value);
  const previousStats = computeDescriptiveStats(previousValues);

  const bodyFatValues = readings
    .map(getBodyFatPercent)
    .filter((v): v is number => v !== null);
  const previousBodyFatValues = previousMeasurements
    .filter((m) => m.metricType === 'weight' && !m.deletedAt)
    .map(getBodyFatPercent)
    .filter((v): v is number => v !== null);

  const totalDays = dateRangeDayCount(params.period);
  const loggedDays = daily.length;
  const changeFromPrevious = changeBetween(previousStats?.mean, stats?.mean);

  const weeklyPace =
    changeFromPrevious && totalDays > 0
      ? changeFromPrevious.absolute / (totalDays / 7)
      : null;

  const timed: TimedValue[] = daily
    .filter((d) => d.weight !== null)
    .map((d) => ({ at: d.day, value: d.weight! }));

  return {
    period: params.period,
    stats,
    daily,
    contiguousSeries,
    latest: readings.length === 0 ? null : readings[readings.length - 1]!,
    startingWeight: values.length === 0 ? null : values[0]!,
    baseline: stats?.mean ?? null,
    changeFromPrevious,
    trend: analyseTrend(timed, { meaningfulChange: 0.5 }),
    loggedDays,
    totalDays,
    completeness: totalDays === 0 ? 0 : loggedDays / totalDays,
    weeklyPace,
    bodyFatLatest:
      bodyFatValues.length === 0 ? null : bodyFatValues[bodyFatValues.length - 1]!,
    bodyFatChange: changeBetween(
      previousBodyFatValues.length === 0
        ? null
        : previousBodyFatValues.reduce((a, b) => a + b, 0) /
            previousBodyFatValues.length,
      bodyFatValues.length === 0
        ? null
        : bodyFatValues.reduce((a, b) => a + b, 0) / bodyFatValues.length,
    ),
  };
}

function buildDailyWeightPoints(
  readings: readonly Measurement[],
  smoothingWindow: number,
): WeightDailyPoint[] {
  const buckets = new Map<string, { day: Date; values: number[] }>();
  for (const r of readings) {
    const day = startOfLocalDay(new Date(r.recordedAt));
    const key = toLocalDayString(day);
    const existing = buckets.get(key);
    if (existing) {
      existing.values.push(r.value);
    } else {
      buckets.set(key, { day, values: [r.value] });
    }
  }

  const sortedEntries = [...buckets.entries()].sort(([a], [b]) => a.localeCompare(b));
  const rawMeans = sortedEntries.map(
    ([, b]) => b.values.reduce((acc, v) => acc + v, 0) / b.values.length,
  );
  const smoothed = movingAverage(rawMeans, smoothingWindow);

  return sortedEntries.map(([localDay, b], idx) => ({
    day: b.day,
    localDay,
    weight: rawMeans[idx]!,
    smoothing: smoothed[idx] ?? null,
    sampleCount: b.values.length,
  }));
}

export function computeGoalProgress(params: {
  target: number;
  current: number;
  start: number;
}): GoalProgress {
  const span = params.target - params.start;
  if (span === 0) {
    return {
      target: params.target,
      current: params.current,
      start: params.start,
      percentAchieved: params.current === params.target ? 1 : 0,
      remaining: params.current === params.target ? 0 : null,
      hasPassedTarget: false,
    };
  }

  const achieved = (params.current - params.start) / span;
  const clamped = Math.max(0, Math.min(1, achieved));
  const remaining = Math.abs(params.target - params.current);

  return {
    target: params.target,
    current: params.current,
    start: params.start,
    percentAchieved: clamped,
    remaining: achieved >= 1 ? 0 : remaining,
    hasPassedTarget: achieved > 1,
  };
}
