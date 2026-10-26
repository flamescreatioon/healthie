/// Descriptive statistics over a sample of health readings.
///
/// Pure functions with no dependency on Flutter, Drift, or the clock, so they
/// are trivially testable and always reproducible from the stored records.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Summary statistics for one metric over one period.
@immutable
class DescriptiveStats {
  const DescriptiveStats({
    required this.count,
    required this.mean,
    required this.median,
    required this.min,
    required this.max,
    this.standardDeviation,
  });

  /// How many readings the statistics are based on.
  final int count;

  /// The arithmetic mean.
  final double mean;

  /// The median — the 50th percentile.
  final double median;

  /// The smallest reading.
  final double min;

  /// The largest reading.
  final double max;

  /// The sample standard deviation, or null when fewer than two readings
  /// exist — a standard deviation over one point is not meaningful.
  final double? standardDeviation;

  /// Computes the statistics for [values].
  ///
  /// Returns null when there is nothing to summarise. An empty dataset is a
  /// normal state on day one, not an error.
  static DescriptiveStats? from(List<double> values) {
    if (values.isEmpty) return null;

    final sorted = List<double>.of(values)..sort();
    final count = sorted.length;
    final sum = sorted.fold<double>(0, (a, b) => a + b);
    final mean = sum / count;

    final median = _median(sorted);
    final min = sorted.first;
    final max = sorted.last;

    double? standardDeviation;
    if (count > 1) {
      final squaredDeltas =
          sorted.map((value) => (value - mean) * (value - mean)).toList();
      final variance = squaredDeltas.fold<double>(0, (a, b) => a + b) /
          (count - 1);
      standardDeviation = math.sqrt(variance);
    }

    return DescriptiveStats(
      count: count,
      mean: mean,
      median: median,
      min: min,
      max: max,
      standardDeviation: standardDeviation,
    );
  }

  static double _median(List<double> sorted) {
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[middle];
    return (sorted[middle - 1] + sorted[middle]) / 2;
  }
}

/// A value at a point in time.
@immutable
class TimedValue {
  const TimedValue({required this.at, required this.value});

  /// When the value was recorded.
  final DateTime at;

  /// The value itself.
  final double value;
}

/// A day in a series, with the value aggregated across that day.
@immutable
class DailyPoint {
  const DailyPoint({
    required this.day,
    required this.value,
    required this.sampleCount,
  });

  /// Local midnight of the day.
  final DateTime day;

  /// The aggregated value for the day, or null when nothing was recorded.
  final double? value;

  /// How many readings contributed to [value].
  final int sampleCount;

  /// Whether anything was recorded on this day.
  bool get hasValue => value != null;
}

/// A centred moving average over a series.
///
/// Positions without a complete window are `null` rather than an invented
/// value — a chart that starts its average on day one is showing something
/// that was never measured.
List<double?> movingAverage(List<double?> values, int window) {
  if (window <= 1) return List<double?>.of(values);
  final result = List<double?>.filled(values.length, null);
  for (var i = window - 1; i < values.length; i++) {
    final slice = values.sublist(i - window + 1, i + 1);
    if (slice.any((value) => value == null)) continue;
    final total = slice.fold<double>(0, (a, b) => a + b!);
    result[i] = total / window;
  }
  return result;
}

/// Aggregates readings into one value per local day.
///
/// Multiple readings on the same day are averaged — the daily mean, which is
/// a different quantity from the mean of all individual readings.
List<DailyPoint> aggregateByDay(List<TimedValue> readings) {
  if (readings.isEmpty) return const [];

  final buckets = <DateTime, List<double>>{};
  for (final reading in readings) {
    final day = DateTime(
      reading.at.toLocal().year,
      reading.at.toLocal().month,
      reading.at.toLocal().day,
    );
    buckets.putIfAbsent(day, () => <double>[]).add(reading.value);
  }

  final days = buckets.keys.toList()..sort();
  return days
      .map(
        (day) => DailyPoint(
          day: day,
          value: buckets[day]!.fold<double>(0, (a, b) => a + b) / buckets[day]!.length,
          sampleCount: buckets[day]!.length,
        ),
      )
      .toList();
}

/// The absolute change between two values, or null when it cannot be computed.
///
/// A percentage change is only meaningful when the baseline is non-zero; a
/// percentage change from zero is not reported rather than reported as
/// infinity.
class Change {
  const Change({required this.absolute, required this.relative});

  /// The difference, in the metric's unit.
  final double absolute;

  /// The proportional change, as a fraction (0.1 is ten per cent).
  final double? relative;

  /// The change as a percentage, or null when the baseline was zero.
  double? get relativePercent =>
      relative == null ? null : relative! * 100;

  /// Computes the change from [baseline] to [current].
  static Change? between(double? baseline, double? current) {
    if (baseline == null || current == null) return null;
    final absolute = current - baseline;
    final relative = baseline == 0 ? null : absolute / baseline;
    return Change(absolute: absolute, relative: relative);
  }
}
