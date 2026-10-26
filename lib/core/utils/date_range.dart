/// A closed, inclusive-start / exclusive-end date range.
///
/// Deliberately not Flutter's `DateTimeRange`: that type lives in
/// `package:flutter/material.dart` and the domain layer must stay independent
/// of presentation concerns.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'date_range.freezed.dart';

@freezed
abstract class DateRange with _$DateRange {
  const factory DateRange({
    required DateTime start,
    required DateTime end,
  }) = _DateRange;

  const DateRange._();

  /// A range covering the [days] local days ending on [end].
  factory DateRange.endingOn(DateTime end, int days) {
    final local = end.toLocal();
    return DateRange(
      start: DateTime(local.year, local.month, local.day - (days - 1)),
      end: DateTime(local.year, local.month, local.day + 1),
    );
  }

  /// Whether [instant] falls inside the range.
  bool contains(DateTime instant) =>
      !instant.isBefore(start) && instant.isBefore(end);

  /// The number of whole days the range spans, at least one.
  ///
  /// Counted on the calendar, so a range containing a daylight-saving
  /// transition still spans the number of days the user sees.
  int get dayCount {
    final s = start.toLocal();
    final e = end.toLocal();
    final calendarStart = DateTime.utc(s.year, s.month, s.day);
    final calendarEnd = DateTime.utc(e.year, e.month, e.day);
    final days = calendarEnd.difference(calendarStart).inDays;
    return days < 1 ? 1 : days;
  }

  /// The range immediately before this one, of the same length.
  DateRange get previous {
    final days = dayCount;
    final s = start.toLocal();
    return DateRange(
      start: DateTime(s.year, s.month, s.day - days),
      end: DateTime(s.year, s.month, s.day),
    );
  }
}
