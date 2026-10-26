# ADR 0002 — Local-day grouping, not UTC days

## Status

Accepted

## Context

Daily rollups must group by the user's own calendar day, not by UTC. A reading
taken at 23:30 local belongs to that local day even though it is already the
next day in UTC. A dashboard that shows yesterday's data on today is a bug
users cannot explain away.

Two implementation choices were considered:

1. **Compute the day at query time** — group by `recorded_at` converted to
   local time in SQL.
2. **Store the day at write time** — denormalise `local_day` (local midnight)
   as a column when the row is written.

## Decision

**Option 2.** Store `local_day` at write time.

### Rationale

- **Correctness across time zones and DST.** Computing local day at query time
  depends on the server's or device's current time zone, which changes when
  the user travels. Storing the day freezes the user's day grouping at the
  moment of recording — past days keep their original grouping, which is what
  people expect from a personal log.
- **Query speed.** "Everything recorded on this day" is one indexed scan.

### Consequences

- All day arithmetic is calendar-based, not 24-hour-based: `DateTime(y, m, d + 1)`
  is used rather than `add(Duration(days: 1))`, because on a daylight-saving
  day the latter lands at 01:00 the next morning rather than at midnight.
- If the user changes time zones, past days keep their original grouping by
  design.

## Related

- `lib/core/utils/date_utils.dart` — `startOfLocalDay`, `localDaysBetween`,
  `daysBetween`, all calendar-based.
