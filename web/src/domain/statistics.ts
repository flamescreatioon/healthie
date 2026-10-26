/**
 * Descriptive statistics over a sample of health readings
 * (1:1 port of `lib/features/analytics/domain/statistics.dart`).
 */

import { startOfLocalDay, toLocalDayString } from './date-utils';

export interface DescriptiveStats {
  readonly count: number;
  readonly mean: number;
  readonly median: number;
  readonly min: number;
  readonly max: number;
  readonly standardDeviation: number | null;
}

export function computeDescriptiveStats(values: readonly number[]): DescriptiveStats | null {
  if (values.length === 0) return null;
  const sorted = [...values].sort((a, b) => a - b);
  const count = sorted.length;
  const sum = sorted.reduce((acc, v) => acc + v, 0);
  const mean = sum / count;

  const middle = Math.floor(count / 2);
  const median =
    count % 2 === 1
      ? sorted[middle]!
      : (sorted[middle - 1]! + sorted[middle]!) / 2;

  const min = sorted[0]!;
  const max = sorted[count - 1]!;

  let standardDeviation: number | null = null;
  if (count > 1) {
    const variance =
      sorted.reduce((acc, v) => acc + (v - mean) * (v - mean), 0) / (count - 1);
    standardDeviation = Math.sqrt(variance);
  }

  return {
    count,
    mean,
    median,
    min,
    max,
    standardDeviation,
  };
}

export interface TimedValue {
  readonly at: Date;
  readonly value: number;
}

export interface DailyPoint {
  readonly day: Date;
  readonly localDay: string;
  readonly value: number | null;
  readonly sampleCount: number;
}

/**
 * Moving average over a series. Positions without a complete window are `null`
 * rather than an invented value.
 */
export function movingAverage(
  values: readonly (number | null)[],
  windowSize: number,
): (number | null)[] {
  if (windowSize <= 1) return [...values];
  const result: (number | null)[] = new Array(values.length).fill(null);
  for (let i = windowSize - 1; i < values.length; i++) {
    const slice = values.slice(i - windowSize + 1, i + 1);
    if (slice.some((v) => v === null)) continue;
    const total = slice.reduce<number>((acc, v) => acc + (v ?? 0), 0);
    result[i] = total / windowSize;
  }
  return result;
}

/**
 * Aggregates readings into one value per local day (daily arithmetic mean).
 */
export function aggregateByDay(readings: readonly TimedValue[]): DailyPoint[] {
  if (readings.length === 0) return [];
  const buckets = new Map<string, { day: Date; values: number[] }>();

  for (const r of readings) {
    const day = startOfLocalDay(r.at);
    const key = toLocalDayString(day);
    const existing = buckets.get(key);
    if (existing) {
      existing.values.push(r.value);
    } else {
      buckets.set(key, { day, values: [r.value] });
    }
  }

  return [...buckets.entries()]
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([localDay, entry]) => ({
      day: entry.day,
      localDay,
      value: entry.values.reduce((a, b) => a + b, 0) / entry.values.length,
      sampleCount: entry.values.length,
    }));
}

export interface Change {
  readonly absolute: number;
  readonly relative: number | null;
  readonly relativePercent: number | null;
}

export function changeBetween(
  baseline: number | null | undefined,
  current: number | null | undefined,
): Change | null {
  if (
    baseline === null ||
    baseline === undefined ||
    current === null ||
    current === undefined
  ) {
    return null;
  }
  const absolute = current - baseline;
  const relative = baseline === 0 ? null : absolute / baseline;
  return {
    absolute,
    relative,
    relativePercent: relative === null ? null : relative * 100,
  };
}
