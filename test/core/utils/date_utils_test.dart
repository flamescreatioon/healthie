import 'package:flutter_test/flutter_test.dart';
import 'package:healthie/core/utils/date_range.dart';
import 'package:healthie/core/utils/date_utils.dart';

void main() {
  group('local-day grouping', () {
    test('groups a 23:30 measurement into the local day', () {
      final at = DateTime(2026, 3, 10, 23, 30);
      expect(startOfLocalDay(at), DateTime(2026, 3, 10));
    });

    test('groups a 00:00 measurement into the local day', () {
      final at = DateTime(2026, 3, 10);
      expect(startOfLocalDay(at), DateTime(2026, 3, 10));
    });

    test('the exclusive end of a day is the next local midnight', () {
      final at = DateTime(2026, 3, 10, 18, 45);
      expect(endOfLocalDay(at), DateTime(2026, 3, 11));
    });

    test('recognises the same local day across representations', () {
      expect(isSameLocalDay(DateTime(2026, 3, 10, 0, 1), DateTime(2026, 3, 10, 23, 59)),
          isTrue);
      expect(isSameLocalDay(DateTime(2026, 3, 10, 23, 59), DateTime(2026, 3, 11)),
          isFalse);
    });
  });

  group('day counting', () {
    test('counts whole calendar days', () {
      expect(daysBetween(DateTime(2026, 3, 1), DateTime(2026, 3, 8)), 7);
    });

    test('counts backwards when the order is reversed', () {
      expect(daysBetween(DateTime(2026, 3, 8), DateTime(2026, 3, 1)), -7);
    });

    test('treats a leap day as part of the month', () {
      expect(daysBetween(DateTime(2028, 2, 28), DateTime(2028, 3, 1)), 2);
    });
  });

  group('localDaysBetween', () {
    test('returns a contiguous list of days', () {
      final days = localDaysBetween(
        DateTime(2026, 3, 1),
        DateTime(2026, 3, 5),
      );
      expect(days, hasLength(5));
      expect(days.first, DateTime(2026, 3, 1));
      expect(days.last, DateTime(2026, 3, 5));
    });

    test('returns an empty list when the range is reversed', () {
      expect(
        localDaysBetween(DateTime(2026, 3, 5), DateTime(2026, 3, 1)),
        isEmpty,
      );
    });

    test('crosses a month boundary', () {
      final days = localDaysBetween(
        DateTime(2026, 1, 30),
        DateTime(2026, 2, 2),
      );
      expect(days, hasLength(4));
      expect(days[1], DateTime(2026, 1, 31));
      expect(days[2], DateTime(2026, 2, 1));
    });

    test('every returned day is at local midnight', () {
      final days = localDaysBetween(DateTime(2026, 3, 1), DateTime(2026, 3, 5));
      for (final day in days) {
        expect(day.hour, 0);
        expect(day.minute, 0);
        expect(day.second, 0);
      }
    });
  });

  group('weeks and months', () {
    test('starts the week on Monday', () {
      // 2026-03-11 is a Wednesday.
      expect(startOfLocalWeek(DateTime(2026, 3, 11)), DateTime(2026, 3, 9));
    });

    test('ends the month at the start of the next month', () {
      expect(endOfLocalMonth(DateTime(2026, 2, 15)), DateTime(2026, 3, 1));
    });
  });

  group('circadian windows', () {
    test('06:00 is in the morning window', () {
      expect(isMorningHour(DateTime(2026, 3, 10, 6)), isTrue);
    });

    test('11:59 is in the morning window', () {
      expect(isMorningHour(DateTime(2026, 3, 10, 11, 59)), isTrue);
    });

    test('12:00 is not in the morning window', () {
      expect(isMorningHour(DateTime(2026, 3, 10, 12)), isFalse);
    });

    test('18:00 is in the evening window', () {
      expect(isEveningHour(DateTime(2026, 3, 10, 18)), isTrue);
    });

    test('17:59 is not in the evening window', () {
      expect(isEveningHour(DateTime(2026, 3, 10, 17, 59)), isFalse);
    });
  });

  group('labels', () {
    test('labels today and yesterday relative to now', () {
      final now = DateTime(2026, 3, 10, 12);
      expect(relativeDayLabel(now, now: now), 'Today');
      expect(
        relativeDayLabel(DateTime(2026, 3, 9, 12), now: now),
        'Yesterday',
      );
    });

    test('formats a time of day', () {
      expect(timeOfDayLabel(DateTime(2026, 3, 10, 8, 5)), '8:05 AM');
      expect(timeOfDayLabel(DateTime(2026, 3, 10, 20, 5)), '8:05 PM');
    });
  });

  group('DateRange', () {
    test('counts the days it spans', () {
      final range = DateRange(
        start: DateTime(2026, 3, 1),
        end: DateTime(2026, 3, 31),
      );
      expect(range.dayCount, 30);
    });

    test('endingOn covers the requested number of days', () {
      final range = DateRange.endingOn(DateTime(2026, 3, 10, 14), 7);
      expect(range.dayCount, 7);
      expect(range.start, DateTime(2026, 3, 4));
      expect(range.end, DateTime(2026, 3, 11));
    });

    test('the previous period has the same length and ends where this begins',
        () {
      final range = DateRange(
        start: DateTime(2026, 3, 1),
        end: DateTime(2026, 3, 31),
      );
      final previous = range.previous;
      expect(previous.dayCount, range.dayCount);
      expect(previous.end, range.start);
    });

    test('contains excludes the exclusive end', () {
      final range = DateRange(
        start: DateTime(2026, 3, 1),
        end: DateTime(2026, 3, 2),
      );
      expect(range.contains(DateTime(2026, 3, 1, 12)), isTrue);
      expect(range.contains(DateTime(2026, 3, 2)), isFalse);
    });
  });
}
