/**
 * Half-open `[start, end)` date range in local calendar days
 * (1:1 port of `lib/core/utils/date_range.dart`).
 */

import { daysBetween, startOfLocalDay } from './date-utils';

export type AnalysisRangeDays = 7 | 30 | 90;

export interface DateRange {
  readonly start: Date;
  readonly end: Date;
}

export function createDateRange(start: Date, end: Date): DateRange {
  return { start, end };
}

export function dateRangeDayCount(range: DateRange): number {
  return Math.max(0, daysBetween(range.start, range.end));
}

export function dateRangeEndingOn(anchor: Date, days: number): DateRange {
  const today = startOfLocalDay(anchor);
  const start = new Date(
    today.getFullYear(),
    today.getMonth(),
    today.getDate() - (days - 1),
    0,
    0,
    0,
    0,
  );
  const end = new Date(
    today.getFullYear(),
    today.getMonth(),
    today.getDate() + 1,
    0,
    0,
    0,
    0,
  );
  return { start, end };
}

export function previousDateRange(range: DateRange): DateRange {
  const count = dateRangeDayCount(range);
  const prevStart = new Date(
    range.start.getFullYear(),
    range.start.getMonth(),
    range.start.getDate() - count,
    0,
    0,
    0,
    0,
  );
  return {
    start: prevStart,
    end: range.start,
  };
}

export function dateRangeContains(range: DateRange, instant: Date): boolean {
  const t = instant.getTime();
  return t >= range.start.getTime() && t < range.end.getTime();
}
