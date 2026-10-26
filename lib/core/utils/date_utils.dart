/// Date helpers built around the **local-day rule**.
///
/// Healthie's daily rollups group by the user's own calendar day, never by
/// UTC. A reading taken at 23:30 local belongs to that local day even though
/// it is already the next day in UTC. Getting this wrong produces dashboards
/// that show yesterday's data on today, and no user can explain it away.
///
/// The device's current local offset is used. Dart's core library carries no
/// IANA time-zone database, so a profile's stored zone is used for display
/// and export only — see `docs/adr/0002-local-day-grouping.md`.
library;

/// The start of the local calendar day containing [instant].
DateTime startOfLocalDay(DateTime instant) {
  final local = instant.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// The exclusive end of the local calendar day containing [instant].
///
/// Built from the calendar rather than by adding 24 hours: on a
/// daylight-saving transition day, local midnight plus 24 hours is 01:00 the
/// following morning, not the following midnight.
DateTime endOfLocalDay(DateTime instant) {
  final local = instant.toLocal();
  return DateTime(local.year, local.month, local.day + 1);
}

/// The local calendar day containing [instant], at local midnight.
DateTime localDayOf(DateTime instant) => startOfLocalDay(instant);

/// Whether two instants fall on the same local calendar day.
bool isSameLocalDay(DateTime a, DateTime b) {
  final la = a.toLocal();
  final lb = b.toLocal();
  return la.year == lb.year && la.month == lb.month && la.day == lb.day;
}

/// The number of whole local days from [from] to [to].
///
/// Negative when [to] precedes [from]. Counted on the calendar, so a
/// day-light-saving day still counts as one day.
int daysBetween(DateTime from, DateTime to) {
  final a = from.toLocal();
  final b = to.toLocal();
  final calendarA = DateTime.utc(a.year, a.month, a.day);
  final calendarB = DateTime.utc(b.year, b.month, b.day);
  return calendarB.difference(calendarA).inDays;
}

/// Every local calendar day from [start] to [end], inclusive.
///
/// The list is contiguous: a day with no measurements is still present, so
/// charts can show a gap rather than silently compressing time.
List<DateTime> localDaysBetween(DateTime start, DateTime end) {
  final first = startOfLocalDay(start);
  final last = startOfLocalDay(end);
  if (last.isBefore(first)) return const [];
  final days = <DateTime>[];
  var cursor = first;
  while (!cursor.isAfter(last)) {
    days.add(cursor);
    final local = cursor;
    cursor = DateTime(local.year, local.month, local.day + 1);
  }
  return days;
}

/// The local day of the week containing [instant], starting on Monday.
DateTime startOfLocalWeek(DateTime instant) {
  final local = instant.toLocal();
  return DateTime(
    local.year,
    local.month,
    local.day - (local.weekday - DateTime.monday),
  );
}

/// The start of the local month containing [instant].
DateTime startOfLocalMonth(DateTime instant) {
  final local = instant.toLocal();
  return DateTime(local.year, local.month);
}

/// The exclusive end of the local month containing [instant].
DateTime endOfLocalMonth(DateTime instant) =>
    DateTime(instant.toLocal().year, instant.toLocal().month + 1);

/// Whether [instant] falls in the morning window (06:00–11:59 local).
///
/// Used by the circadian comparison, which compares morning readings against
/// evening readings.
bool isMorningHour(DateTime instant) {
  final local = instant.toLocal();
  return local.hour >= 6 && local.hour < 12;
}

/// Whether [instant] falls in the evening window (18:00–23:59 local).
bool isEveningHour(DateTime instant) {
  final local = instant.toLocal();
  return local.hour >= 18;
}

/// A human label for a day relative to [now]: "Today", "Yesterday", or a date.
String relativeDayLabel(DateTime instant, {required DateTime now}) {
  final difference = daysBetween(instant, now);
  if (difference == 0) return 'Today';
  if (difference == 1) return 'Yesterday';
  if (difference == -1) return 'Tomorrow';
  final local = instant.toLocal();
  return '${_weekdayName(local.weekday)}, ${_monthName(local.month)} ${local.day}';
}

/// "Sunday, Oct 22" — used for history group headings.
String longDayLabel(DateTime instant) {
  final local = instant.toLocal();
  return '${_weekdayName(local.weekday)}, ${_monthName(local.month)} ${local.day}';
}

/// "Oct 22, 2023"
String mediumDateLabel(DateTime instant) {
  final local = instant.toLocal();
  return '${_monthName(local.month)} ${local.day}, ${local.year}';
}

/// "Oct 22"
String shortDateLabel(DateTime instant) {
  final local = instant.toLocal();
  return '${_monthName(local.month)} ${local.day}';
}

/// "8:15 AM"
String timeOfDayLabel(DateTime instant) {
  final local = instant.toLocal();
  final hour = local.hour == 0 ? 12 : (local.hour > 12 ? local.hour - 12 : local.hour);
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $suffix';
}

/// "8:15 AM" on the same day, or "Oct 22, 8:15 AM" for another day.
String timestampLabel(DateTime instant, {required DateTime now}) {
  final time = timeOfDayLabel(instant);
  if (isSameLocalDay(instant, now)) return time;
  return '${shortDateLabel(instant)}, $time';
}

String _weekdayName(int weekday) => switch (weekday) {
      DateTime.monday => 'Monday',
      DateTime.tuesday => 'Tuesday',
      DateTime.wednesday => 'Wednesday',
      DateTime.thursday => 'Thursday',
      DateTime.friday => 'Friday',
      DateTime.saturday => 'Saturday',
      _ => 'Sunday',
    };

String _monthName(int month) => switch (month) {
      DateTime.january => 'Jan',
      DateTime.february => 'Feb',
      DateTime.march => 'Mar',
      DateTime.april => 'Apr',
      DateTime.may => 'May',
      DateTime.june => 'Jun',
      DateTime.july => 'Jul',
      DateTime.august => 'Aug',
      DateTime.september => 'Sep',
      DateTime.october => 'Oct',
      DateTime.november => 'Nov',
      _ => 'Dec',
    };
