/// Trend detection for irregularly spaced health readings.
///
/// Health data is not evenly sampled: someone weighs in most mornings for a
/// fortnight and then not at all for a week. A least-squares slope over raw
/// timestamps treats that gap as "no change" and quietly biases the result.
///
/// The **Theil–Sen estimator** is used instead: it is the median of the slopes
/// of every pair of observations. It is robust to the outliers and the uneven
/// spacing that health data always has.
///
/// Two points are not a trend. With fewer than three observations the result
/// says so explicitly rather than reporting a slope that looks authoritative.
library;

import 'package:flutter/foundation.dart';

import 'statistics.dart';

/// The direction of a detected trend.
enum TrendDirection {
  /// The value is rising.
  increasing,

  /// The value is falling.
  decreasing,

  /// The variation is within normal fluctuation.
  stable,

  /// There are not enough observations to say.
  insufficientData,
}

/// The outcome of a trend analysis.
@immutable
class TrendResult {
  const TrendResult({
    required this.direction,
    required this.sampleCount,
    required this.spanDays,
    this.slopePerDay,
    this.totalChange,
    this.limitation,
  });

  /// The direction the data supports.
  final TrendDirection direction;

  /// How many observations the result is based on.
  final int sampleCount;

  /// How many days the observations span.
  final double spanDays;

  /// The estimated change per day.
  final double? slopePerDay;

  /// The estimated total change across the span.
  final double? totalChange;

  /// A sentence explaining what the result does *not* establish.
  final String? limitation;

  /// Whether the result supports a directional statement at all.
  bool get hasDirection => direction != TrendDirection.insufficientData;
}

/// Analyses the direction of a series of readings.
///
/// [meaningfulChange] is the absolute change across the whole span that must
/// be exceeded before a direction is reported. It is metric-specific because
/// 0.2 kg of weight is noise while 5 mmHg of systolic pressure is not.
///
/// Returns [TrendDirection.insufficientData] for fewer than three
/// observations, with an explanation attached.
TrendResult analyseTrend(
  List<TimedValue> readings, {
  required double meaningfulChange,
}) {
  if (readings.length < 2) {
    return TrendResult(
      direction: TrendDirection.insufficientData,
      sampleCount: readings.length,
      spanDays: 0,
      limitation: readings.isEmpty
          ? 'There are no readings to analyse yet.'
          : 'There is only one reading, so no trend can be established.',
    );
  }

  final sorted = List<TimedValue>.of(readings)
    ..sort((a, b) => a.at.compareTo(b.at));
  final first = sorted.first;
  final last = sorted.last;
  final spanDays = last.at.difference(first.at).inHours / 24;

  if (sorted.length < 3 || spanDays <= 0) {
    return TrendResult(
      direction: TrendDirection.insufficientData,
      sampleCount: sorted.length,
      spanDays: spanDays,
      slopePerDay: spanDays > 0 ? (last.value - first.value) / spanDays : null,
      totalChange: spanDays > 0 ? last.value - first.value : null,
      limitation:
          'Only ${sorted.length} readings over ${spanDays.round()} day'
          '${spanDays.round() == 1 ? '' : 's'}. Two points cannot establish a '
          'reliable trend.',
    );
  }

  final slope = _theilSenSlope(sorted);
  final totalChange = slope * spanDays;

  final TrendDirection direction;
  if (totalChange.abs() < meaningfulChange) {
    direction = TrendDirection.stable;
  } else if (totalChange > 0) {
    direction = TrendDirection.increasing;
  } else {
    direction = TrendDirection.decreasing;
  }

  return TrendResult(
    direction: direction,
    sampleCount: sorted.length,
    spanDays: spanDays,
    slopePerDay: slope,
    totalChange: totalChange,
  );
}

/// The median of the slopes of every pair of observations.
double _theilSenSlope(List<TimedValue> sorted) {
  final slopes = <double>[];
  for (var i = 0; i < sorted.length - 1; i++) {
    for (var j = i + 1; j < sorted.length; j++) {
      final days = sorted[j].at.difference(sorted[i].at).inHours / 24;
      if (days <= 0) continue;
      slopes.add((sorted[j].value - sorted[i].value) / days);
    }
  }
  if (slopes.isEmpty) return 0;
  slopes.sort();
  final middle = slopes.length ~/ 2;
  if (slopes.length.isOdd) return slopes[middle];
  return (slopes[middle - 1] + slopes[middle]) / 2;
}
