/**
 * Date helpers built around the **local-day rule** (1:1 port of `date_utils.dart`
 * and `docs/adr/0002-local-day-grouping.md`).
 *
 * Healthie's daily rollups group by the user's own calendar day, never by UTC.
 * A reading taken at 23:30 local belongs to that local day even though it is
 * already the next day in UTC.
 */

const WEEKDAYS = [
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
] as const;

const MONTHS_SHORT = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
] as const;

/**
 * The start of the local calendar day containing `instant` (local midnight).
 */
export function startOfLocalDay(instant: Date): Date {
  return new Date(instant.getFullYear(), instant.getMonth(), instant.getDate(), 0, 0, 0, 0);
}

/**
 * The exclusive end of the local calendar day containing `instant`.
 * Built from calendar date + 1 day rather than adding 24h so DST transitions
 * land on the next local midnight, not 01:00 or 23:00.
 */
export function endOfLocalDay(instant: Date): Date {
  return new Date(instant.getFullYear(), instant.getMonth(), instant.getDate() + 1, 0, 0, 0, 0);
}

/**
 * Canonical `YYYY-MM-DD` local calendar day string stored alongside `recordedAt`.
 */
export function toLocalDayString(instant: Date): string {
  const year = instant.getFullYear();
  const month = String(instant.getMonth() + 1).padStart(2, '0');
  const day = String(instant.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

/**
 * Parses a `YYYY-MM-DD` local day string (or full ISO string) into a local-midnight `Date`.
 */
export function parseLocalDay(localDay: string): Date {
  const match = /^(\d{4})-(\d{2})-(\d{2})/.exec(localDay);
  if (match) {
    const year = Number(match[1]);
    const month = Number(match[2]) - 1;
    const day = Number(match[3]);
    return new Date(year, month, day, 0, 0, 0, 0);
  }
  const parsed = new Date(localDay);
  return startOfLocalDay(parsed);
}

/**
 * Whether two instants fall on the same local calendar day.
 */
export function isSameLocalDay(a: Date, b: Date): boolean {
  return (
    a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate()
  );
}

/**
 * Whole local calendar days from `from` to `to` (DST-safe via UTC calendar date diff).
 */
export function daysBetween(from: Date, to: Date): number {
  const utcA = Date.UTC(from.getFullYear(), from.getMonth(), from.getDate());
  const utcB = Date.UTC(to.getFullYear(), to.getMonth(), to.getDate());
  return Math.round((utcB - utcA) / 86_400_000);
}

/**
 * Every local calendar day from `start` to `end`, inclusive.
 * Contiguous: missing days are still present so charts render gaps rather than compressing time.
 */
export function localDaysBetween(start: Date, end: Date): Date[] {
  const first = startOfLocalDay(start);
  const last = startOfLocalDay(end);
  if (last.getTime() < first.getTime()) return [];

  const days: Date[] = [];
  let cursor = first;
  while (cursor.getTime() <= last.getTime()) {
    days.push(cursor);
    cursor = new Date(cursor.getFullYear(), cursor.getMonth(), cursor.getDate() + 1, 0, 0, 0, 0);
  }
  return days;
}

/**
 * Start of the local week containing `instant`, starting on Monday.
 */
export function startOfLocalWeek(instant: Date): Date {
  const dayOfWeek = instant.getDay(); // 0 = Sun, 1 = Mon, ...
  const diffFromMonday = dayOfWeek === 0 ? 6 : dayOfWeek - 1;
  return new Date(
    instant.getFullYear(),
    instant.getMonth(),
    instant.getDate() - diffFromMonday,
    0,
    0,
    0,
    0,
  );
}

/**
 * Whether `instant` falls in the morning window (06:00–11:59 local).
 */
export function isMorningHour(instant: Date): boolean {
  const hour = instant.getHours();
  return hour >= 6 && hour < 12;
}

/**
 * Whether `instant` falls in the evening window (18:00–23:59 local).
 */
export function isEveningHour(instant: Date): boolean {
  return instant.getHours() >= 18;
}

export function relativeDayLabel(instant: Date, now: Date): string {
  const diff = daysBetween(instant, now);
  if (diff === 0) return 'Today';
  if (diff === 1) return 'Yesterday';
  if (diff === -1) return 'Tomorrow';
  return longDayLabel(instant);
}

export function longDayLabel(instant: Date): string {
  const weekday = WEEKDAYS[instant.getDay()];
  const month = MONTHS_SHORT[instant.getMonth()];
  return `${weekday}, ${month} ${instant.getDate()}`;
}

export function mediumDateLabel(instant: Date): string {
  const month = MONTHS_SHORT[instant.getMonth()];
  return `${month} ${instant.getDate()}, ${instant.getFullYear()}`;
}

export function shortDateLabel(instant: Date): string {
  const month = MONTHS_SHORT[instant.getMonth()];
  return `${month} ${instant.getDate()}`;
}

export function timeOfDayLabel(instant: Date): string {
  const rawHour = instant.getHours();
  const hour = rawHour === 0 ? 12 : rawHour > 12 ? rawHour - 12 : rawHour;
  const minute = String(instant.getMinutes()).padStart(2, '0');
  const suffix = rawHour < 12 ? 'AM' : 'PM';
  return `${hour}:${minute} ${suffix}`;
}

export function timestampLabel(instant: Date, now: Date): string {
  const time = timeOfDayLabel(instant);
  if (isSameLocalDay(instant, now)) return time;
  return `${shortDateLabel(instant)}, ${time}`;
}
