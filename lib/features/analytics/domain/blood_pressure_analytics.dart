/// Blood-pressure analytics for one period.
///
/// Every number here is derived from stored readings. Nothing is estimated,
/// interpolated, or filled in: a day with no reading is a gap, and the gap is
/// reported as a gap.
library;

import 'package:flutter/foundation.dart';

import '../../../core/utils/date_range.dart';
import '../../../core/utils/date_utils.dart';
import '../../metrics/domain/blood_pressure_guideline.dart';
import '../../metrics/domain/measurement.dart';
import 'statistics.dart';
import 'trend.dart';

/// One day's blood pressure, averaged across that day's readings.
@immutable
class BpDailyPoint {
  const BpDailyPoint({
    required this.day,
    required this.systolic,
    required this.diastolic,
    required this.sampleCount,
  });

  /// Local midnight of the day.
  final DateTime day;

  /// The day's mean systolic pressure, or null when nothing was recorded.
  final double? systolic;

  /// The day's mean diastolic pressure, or null when nothing was recorded.
  final double? diastolic;

  /// How many readings contributed to the day's means.
  final int sampleCount;

  /// Whether anything was recorded on this day.
  bool get hasValue => systolic != null && diastolic != null;
}

/// A systolic/diastolic pair with the number of readings behind it.
@immutable
class BpAverages {
  const BpAverages({
    required this.systolic,
    required this.diastolic,
    required this.sampleCount,
  });

  /// No readings.
  static const BpAverages none =
      BpAverages(systolic: null, diastolic: null, sampleCount: 0);

  /// The mean systolic pressure, in mmHg.
  final double? systolic;

  /// The mean diastolic pressure, in mmHg.
  final double? diastolic;

  /// How many readings contributed.
  final int sampleCount;

  /// Whether any reading contributed.
  bool get hasData => sampleCount > 0;
}

/// The blood-pressure summary for one period.
@immutable
class BpPeriodSummary {
  const BpPeriodSummary({
    required this.period,
    required this.systolic,
    required this.diastolic,
    required this.latest,
    required this.daily,
    required this.distribution,
    required this.morning,
    required this.evening,
    required this.loggedDays,
    required this.totalDays,
    required this.systolicTrend,
    required this.diastolicTrend,
    required this.guideline,
  });

  /// The period the summary covers.
  final DateRange period;

  /// Statistics over **all individual readings** in the period.
  final DescriptiveStats? systolic;

  /// Statistics over **all individual readings** in the period.
  final DescriptiveStats? diastolic;

  /// The most recent reading, or null when there is none.
  final Measurement? latest;

  /// One entry per day with at least one reading, oldest first.
  final List<BpDailyPoint> daily;

  /// How many readings fell into each guideline category.
  final Map<BpCategory, int> distribution;

  /// Readings taken between 06:00 and 11:59 local.
  final BpAverages morning;

  /// Readings taken between 18:00 and 23:59 local.
  final BpAverages evening;

  /// How many distinct local days have at least one reading.
  final int loggedDays;

  /// How many local days the period covers.
  final int totalDays;

  /// The trend of the systolic series over the period.
  final TrendResult systolicTrend;

  /// The trend of the diastolic series over the period.
  final TrendResult diastolicTrend;

  /// The guideline the classification came from.
  final BpGuideline guideline;

  /// The share of days with at least one reading, from 0 to 1.
  double get completeness => totalDays == 0 ? 0 : loggedDays / totalDays;

  /// The number of readings in the period.
  int get readingCount => systolic?.count ?? 0;

  /// The number of readings in the highest severity category present.
  int countIn(BpCategory category) => distribution[category] ?? 0;

  /// The share of readings in [category], from 0 to 1.
  double shareOf(BpCategory category) {
    final total = readingCount;
    if (total == 0) return 0;
    return countIn(category) / total;
  }
}

/// Summarises blood-pressure readings for [period].
///
/// [measurements] must contain only blood-pressure measurements; the caller
/// filters by metric type.
BpPeriodSummary summariseBloodPressure({
  required DateRange period,
  required List<Measurement> measurements,
  BpGuideline guideline = defaultBpGuideline,
}) {
  final readings = measurements
      .where((m) => m.metricType.wireName == 'blood_pressure')
      .toList()
    ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

  final systolicValues = <double>[];
  final diastolicValues = <double>[];
  final distribution = <BpCategory, int>{
    for (final category in BpCategory.values) category: 0,
  };

  for (final reading in readings) {
    systolicValues.add(reading.value);
    final diastolic = reading.secondaryValue;
    if (diastolic == null) continue;
    diastolicValues.add(diastolic);
    final category = guideline.classify(
      systolic: reading.value.round(),
      diastolic: diastolic.round(),
    );
    distribution[category] = (distribution[category] ?? 0) + 1;
  }

  final daily = _dailyMeans(readings);
  final morningReadings =
      readings.where((m) => isMorningHour(m.recordedAt)).toList();
  final eveningReadings =
      readings.where((m) => isEveningHour(m.recordedAt)).toList();

  final totalDays = period.dayCount;
  final loggedDays = daily.length;

  return BpPeriodSummary(
    period: period,
    systolic: DescriptiveStats.from(systolicValues),
    diastolic: DescriptiveStats.from(diastolicValues),
    latest: readings.isEmpty ? null : readings.last,
    daily: daily,
    distribution: distribution,
    morning: _averages(morningReadings),
    evening: _averages(eveningReadings),
    loggedDays: loggedDays,
    totalDays: totalDays,
    systolicTrend: analyseTrend(
      [for (final point in daily) TimedValue(at: point.day, value: point.systolic!)],
      meaningfulChange: 5,
    ),
    diastolicTrend: analyseTrend(
      [
        for (final point in daily)
          TimedValue(at: point.day, value: point.diastolic!)
      ],
      meaningfulChange: 5,
    ),
    guideline: guideline,
  );
}

List<BpDailyPoint> _dailyMeans(List<Measurement> readings) {
  final buckets = <DateTime, List<double>>{};
  final diastolicBuckets = <DateTime, List<double>>{};

  for (final reading in readings) {
    final local = reading.recordedAt.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    buckets.putIfAbsent(day, () => <double>[]).add(reading.value);
    final diastolic = reading.secondaryValue;
    if (diastolic != null) {
      diastolicBuckets.putIfAbsent(day, () => <double>[]).add(diastolic);
    }
  }

  final days = buckets.keys.toList()..sort();
  return days.map((day) {
    final systolics = buckets[day]!;
    final diastolics = diastolicBuckets[day] ?? const <double>[];
    return BpDailyPoint(
      day: day,
      systolic: systolics.fold<double>(0, (a, b) => a + b) / systolics.length,
      diastolic: diastolics.isEmpty
          ? null
          : diastolics.fold<double>(0, (a, b) => a + b) / diastolics.length,
      sampleCount: systolics.length,
    );
  }).toList();
}

BpAverages _averages(List<Measurement> readings) {
  if (readings.isEmpty) return BpAverages.none;
  final systolics = readings.map((m) => m.value).toList();
  final diastolics = readings
      .map((m) => m.secondaryValue)
      .whereType<double>()
      .toList();
  return BpAverages(
    systolic:
        systolics.fold<double>(0, (a, b) => a + b) / systolics.length,
    diastolic: diastolics.isEmpty
        ? null
        : diastolics.fold<double>(0, (a, b) => a + b) / diastolics.length,
    sampleCount: readings.length,
  );
}
