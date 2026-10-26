/**
 * Trend detection using the Theil–Sen estimator
 * (1:1 port of `lib/features/analytics/domain/trend.dart`).
 *
 * Two points are not a trend: fewer than three observations return
 * `insufficient_data` with an explicit limitation sentence.
 */

import type { TimedValue } from './statistics';

export type TrendDirection =
  | 'increasing'
  | 'decreasing'
  | 'stable'
  | 'insufficient_data';

export interface TrendResult {
  readonly direction: TrendDirection;
  readonly sampleCount: number;
  readonly spanDays: number;
  readonly slopePerDay: number | null;
  readonly totalChange: number | null;
  readonly limitation: string | null;
  readonly hasDirection: boolean;
}

export function analyseTrend(
  readings: readonly TimedValue[],
  options: { meaningfulChange: number },
): TrendResult {
  if (readings.length < 2) {
    return {
      direction: 'insufficient_data',
      sampleCount: readings.length,
      spanDays: 0,
      slopePerDay: null,
      totalChange: null,
      limitation:
        readings.length === 0
          ? 'There are no readings to analyse yet.'
          : 'There is only one reading, so no trend can be established.',
      hasDirection: false,
    };
  }

  const sorted = [...readings].sort((a, b) => a.at.getTime() - b.at.getTime());
  const first = sorted[0]!;
  const last = sorted[sorted.length - 1]!;
  const spanHours = Math.floor((last.at.getTime() - first.at.getTime()) / 3_600_000);
  const spanDays = spanHours / 24;

  if (sorted.length < 3 || spanDays <= 0) {
    const roundedDays = Math.round(spanDays);
    return {
      direction: 'insufficient_data',
      sampleCount: sorted.length,
      spanDays,
      slopePerDay: spanDays > 0 ? (last.value - first.value) / spanDays : null,
      totalChange: spanDays > 0 ? last.value - first.value : null,
      limitation: `Only ${sorted.length} readings over ${roundedDays} day${roundedDays === 1 ? '' : 's'}. Two points cannot establish a reliable trend.`,
      hasDirection: false,
    };
  }

  const slope = theilSenSlope(sorted);
  const totalChange = slope * spanDays;

  let direction: TrendDirection;
  if (Math.abs(totalChange) < options.meaningfulChange) {
    direction = 'stable';
  } else if (totalChange > 0) {
    direction = 'increasing';
  } else {
    direction = 'decreasing';
  }

  return {
    direction,
    sampleCount: sorted.length,
    spanDays,
    slopePerDay: slope,
    totalChange,
    limitation: null,
    hasDirection: true,
  };
}

function theilSenSlope(sorted: readonly TimedValue[]): number {
  const slopes: number[] = [];
  for (let i = 0; i < sorted.length - 1; i++) {
    for (let j = i + 1; j < sorted.length; j++) {
      const hours = Math.floor(
        (sorted[j]!.at.getTime() - sorted[i]!.at.getTime()) / 3_600_000,
      );
      const days = hours / 24;
      if (days <= 0) continue;
      slopes.push((sorted[j]!.value - sorted[i]!.value) / days);
    }
  }
  if (slopes.length === 0) return 0;
  slopes.sort((a, b) => a - b);
  const mid = Math.floor(slopes.length / 2);
  if (slopes.length % 2 === 1) return slopes[mid]!;
  return (slopes[mid - 1]! + slopes[mid]!) / 2;
}
