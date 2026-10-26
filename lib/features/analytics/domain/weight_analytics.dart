/// Weight analytics for one period.
///
/// The same rules as everywhere else: nothing is forecast, nothing is
/// invented, and no change is described as good or bad. "−0.4 kg over 30
/// days" is a fact; "great progress" is an opinion the user gets to have for
/// themselves.
library;

import 'package:flutter/foundation.dart';

import '../../../core/units/unit.dart';
import '../../../core/utils/date_range.dart';
import '../../metrics/domain/measurement.dart';
import 'statistics.dart';
import 'trend.dart';

/// One day's weight, with a smoothed overlay.
@immutable
class WeightDailyPoint {
  const WeightDailyPoint({
    required this.day,
    required this.weight,
    required this.smoothing,
    required this.sampleCount,
  });

  /// Local midnight of the day.
  final DateTime day;

  /// The day's mean weight in canonical units (kg), or null when nothing was
  /// recorded.
  final double? weight;

  /// The centred moving average over [smoothingWindow] days, or null until
  /// the window is complete.
  final double? smoothing;

  /// How many readings contributed to [weight].
  final int sampleCount;
}

/// How far the user is towards a goal they set themselves.
@immutable
class GoalProgress {
  const GoalProgress({
    required this.target,
    required this.current,
    required this.start,
    required this.percentAchieved,
    required this.remaining,
    required this.hasPassedTarget,
  });

  /// The target value, in canonical units.
  final double target;

  /// The current value.
  final double current;

  /// The value the goal was measured from.
  final double start;

  /// Progress from 0 to 1. Clamped; overshooting never exceeds 100%.
  final double percentAchieved;

  /// How far is left to the target, in canonical units. Null once the target
  /// has been reached.
  final double? remaining;

  /// Whether the current value has passed the target.
  final bool hasPassedTarget;
}

/// The weight summary for one period.
@immutable
class WeightPeriodSummary {
  const WeightPeriodSummary({
    required this.period,
    required this.stats,
    required this.daily,
    required this.latest,
    required this.startingWeight,
    required this.baseline,
    required this.changeFromPrevious,
    required this.trend,
    required this.loggedDays,
    required this.totalDays,
    required this.bodyFatLatest,
    required this.bodyFatChange,
  });

  /// The period the summary covers.
  final DateRange period;

  /// Statistics over **all individual weigh-ins** in the period.
  final DescriptiveStats? stats;

  /// One entry per day with at least one weigh-in, oldest first.
  final List<WeightDailyPoint> daily;

  /// The most recent weigh-in in the period, or null.
  final Measurement? latest;

  /// The first weigh-in in the period.
  final double? startingWeight;

  /// The mean weight over the period — the baseline level.
  final double? baseline;

  /// The change against the previous comparable period.
  final Change? changeFromPrevious;

  /// The trend of the daily weight series.
  final TrendResult trend;

  /// How many distinct local days have at least one weigh-in.
  final int loggedDays;

  /// How many local days the period covers.
  final int totalDays;

  /// The most recent body-fat percentage recorded in the period.
  final double? bodyFatLatest;

  /// The change in body-fat percentage against the previous comparable
  /// period.
  final Change? bodyFatChange;

  /// The share of days with at least one weigh-in, from 0 to 1.
  double get completeness => totalDays == 0 ? 0 : loggedDays / totalDays;

  /// The mean weight per week, expressed as a change in kg.
  ///
  /// Negative means the weight is falling. This is a description of the
  /// observed rate, never a recommendation.
  double? get weeklyPace {
    final change = changeFromPrevious?.absolute;
    if (change == null || period.dayCount == 0) return null;
    return change / (period.dayCount / 7);
  }
}

/// Summarises weight readings for [period].
///
/// [measurements] must contain only weight measurements.
WeightPeriodSummary summariseWeight({
  required DateRange period,
  required List<Measurement> measurements,
  List<Measurement> previousPeriodMeasurements = const [],
  int smoothingWindow = 7,
}) {
  final readings = measurements
      .where((m) => m.metricType.wireName == 'weight')
      .toList()
    ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

  final values = readings.map((m) => m.value).toList();
  final stats = DescriptiveStats.from(values);

  final daily = _dailyPoints(readings, smoothingWindow: smoothingWindow);

  final previousValues = previousPeriodMeasurements
      .where((m) => m.metricType.wireName == 'weight')
      .map((m) => m.value)
      .toList();
  final previousStats = DescriptiveStats.from(previousValues);

  final bodyFatValues = readings
      .map((m) => m.bodyFatPercent)
      .whereType<double>()
      .toList();
  final previousBodyFatValues = previousPeriodMeasurements
      .map((m) => m.bodyFatPercent)
      .whereType<double>()
      .toList();

  return WeightPeriodSummary(
    period: period,
    stats: stats,
    daily: daily,
    latest: readings.isEmpty ? null : readings.last,
    startingWeight: values.isEmpty ? null : values.first,
    baseline: stats?.mean,
    changeFromPrevious: Change.between(previousStats?.mean, stats?.mean),
    trend: analyseTrend(
      [
        for (final point in daily)
          TimedValue(at: point.day, value: point.weight!)
      ],
      meaningfulChange: 0.5,
    ),
    loggedDays: daily.length,
    totalDays: period.dayCount,
    bodyFatLatest: bodyFatValues.isEmpty ? null : bodyFatValues.last,
    bodyFatChange: Change.between(
      previousBodyFatValues.isEmpty
          ? null
          : previousBodyFatValues.fold<double>(0, (a, b) => a + b) /
              previousBodyFatValues.length,
      bodyFatValues.isEmpty
          ? null
          : bodyFatValues.fold<double>(0, (a, b) => a + b) / bodyFatValues.length,
    ),
  );
}

List<WeightDailyPoint> _dailyPoints(
  List<Measurement> readings, {
  required int smoothingWindow,
}) {
  final buckets = <DateTime, List<double>>{};
  for (final reading in readings) {
    final local = reading.recordedAt.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    buckets.putIfAbsent(day, () => <double>[]).add(reading.value);
  }

  final days = buckets.keys.toList()..sort();
  final rawMeans = days.map((day) {
    final values = buckets[day]!;
    return values.fold<double>(0, (a, b) => a + b) / values.length;
  }).toList();

  final smoothed = movingAverage(rawMeans, smoothingWindow);

  return [
    for (var i = 0; i < days.length; i++)
      WeightDailyPoint(
        day: days[i],
        weight: rawMeans[i],
        smoothing: smoothed[i],
        sampleCount: buckets[days[i]]!.length,
      ),
  ];
}

/// Computes progress towards a user-defined goal.
///
/// Handles a target that has already been reached — and a target that has
/// been overshot, which must not render as a nonsensical over-full bar.
GoalProgress? computeGoalProgress({
  required double target,
  required double current,
  required double start,
}) {
  final span = target - start;
  if (span == 0) {
    return GoalProgress(
      target: target,
      current: current,
      start: start,
      percentAchieved: current == target ? 1 : 0,
      remaining: current == target ? 0 : null,
      hasPassedTarget: false,
    );
  }

  final achieved = (current - start) / span;
  final clamped = achieved.clamp(0.0, 1.0);
  final remaining = (target - current).abs();

  return GoalProgress(
    target: target,
    current: current,
    start: start,
    percentAchieved: clamped,
    remaining: achieved >= 1 ? 0 : remaining,
    hasPassedTarget: achieved > 1,
  );
}

/// Converts a canonical kilogram value into the user's preferred mass unit.
double weightInUnit(double kilograms, Unit unit) {
  if (unit == Unit.kilogram) return kilograms;
  return convert(kilograms, Unit.kilogram, unit);
}
