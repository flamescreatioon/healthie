/// An injectable source of "now".
///
/// Production code uses [SystemClock]. Tests use [FixedClock] so that date
/// grouping, rolling windows, and relative labels are deterministic.
library;

abstract interface class Clock {
  /// The current instant, in the device's local time zone.
  DateTime now();
}

final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// A clock frozen at [instant].
final class FixedClock implements Clock {
  const FixedClock(this.instant);

  final DateTime instant;

  @override
  DateTime now() => instant;
}
