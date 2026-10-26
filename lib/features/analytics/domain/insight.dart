/// Deterministic insight generation.
///
/// Every insight is a reproducible calculation over stored readings. Nothing
/// here invents a measurement, asserts a cause, or claims a diagnosis.
///
/// Each insight carries the measurement it is about, the period it compares
/// against, the actual numbers, the sample size, and any limitation that
/// matters. An insight that cannot be supported by the data is not produced.
library;

import 'package:flutter/foundation.dart';

import '../../../core/utils/date_utils.dart';
import '../../metrics/domain/blood_pressure_guideline.dart';
import 'blood_pressure_analytics.dart';
import 'statistics.dart';
import 'trend.dart';
import 'weight_analytics.dart';

/// The kind of observation an insight makes.
enum InsightKind {
  /// A comparison against a previous period.
  comparison,

  /// How consistently the user has been recording.
  consistency,

  /// A change in a value.
  change,

  /// A statement that there is not enough data.
  sparsity,

  /// A reading that does not fit the recent pattern.
  outlier,
}

/// A single, evidence-backed observation.
@immutable
class Insight {
  const Insight({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    this.sampleCount,
    this.limitation,
  });

  /// A stable identifier, so the UI can key and de-duplicate insights.
  final String id;

  /// The kind of observation.
  final InsightKind kind;

  /// A short headline.
  final String title;

  /// The observation, with its numbers.
  final String body;

  /// How many readings the observation is based on.
  final int? sampleCount;

  /// A limitation the user should know about.
  final String? limitation;
}

/// Builds the insights for the blood-pressure analytics screen.
///
/// [previous] is the immediately preceding comparable period; it may be empty
/// when there is no earlier data.
List<Insight> bloodPressureInsights({
  required BpPeriodSummary current,
  BpPeriodSummary? previous,
}) {
  final insights = <Insight>[];
  final systolic = current.systolic;
  final diastolic = current.diastolic;

  if (systolic == null || systolic.count == 0) {
    insights.add(
      const Insight(
        id: 'bp.no-data',
        kind: InsightKind.sparsity,
        title: 'No blood pressure readings yet',
        body:
            'Record a blood pressure reading to start building your trend. '
            'Readings are classified against the AHA/ACC 2017 guideline.',
      ),
    );
    return insights;
  }

  // Comparison against the previous period.
  if (previous != null && previous.systolic != null) {
    final change = Change.between(previous.systolic!.mean, systolic.mean);
    if (change != null && change.absolute.abs() >= 1) {
      final higher = change.absolute > 0;
      insights.add(
        Insight(
          id: 'bp.systolic-comparison',
          kind: InsightKind.comparison,
          title: higher ? 'Systolic pressure is up' : 'Systolic pressure is down',
          body:
              'Your average systolic pressure was '
              '${change.absolute.abs().toStringAsFixed(0)} mmHg '
              '${higher ? 'higher' : 'lower'} than in the previous '
              '${previous.period.dayCount}-day period '
              '(${systolic.mean.toStringAsFixed(0)} mmHg versus '
              '${previous.systolic!.mean.toStringAsFixed(0)} mmHg).',
          sampleCount: systolic.count,
          limitation:
              'A change in an average is a description of the recorded data. '
              'It is not a diagnosis and does not establish a cause.',
        ),
      );
    }
  }

  // Consistency.
  insights.add(
    Insight(
      id: 'bp.consistency',
      kind: InsightKind.consistency,
      title: 'Recording consistency',
      body:
          'You recorded blood pressure on ${current.loggedDays} of the last '
          '${current.totalDays} days '
          '(${(current.completeness * 100).round()}%).',
      sampleCount: systolic.count,
      limitation: current.loggedDays < current.totalDays ~/ 2
          ? 'Frequent gaps limit how confidently a trend can be described.'
          : null,
    ),
  );

  // Trend.
  final trend = current.systolicTrend;
  if (trend.direction == TrendDirection.insufficientData) {
    insights.add(
      Insight(
        id: 'bp.trend',
        kind: InsightKind.sparsity,
        title: 'Not enough readings for a reliable trend',
        body: trend.limitation ??
            'There are not enough measurements to calculate a reliable trend.',
        sampleCount: trend.sampleCount,
      ),
    );
  } else {
    insights.add(
      Insight(
        id: 'bp.trend',
        kind: InsightKind.change,
        title: switch (trend.direction) {
          TrendDirection.increasing => 'Systolic pressure is trending up',
          TrendDirection.decreasing => 'Systolic pressure is trending down',
          TrendDirection.stable => 'Systolic pressure is stable',
          TrendDirection.insufficientData => 'Trend unavailable',
        },
        body:
            'Across ${trend.sampleCount} days of readings the estimated change '
            'is ${trend.totalChange!.toStringAsFixed(1)} mmHg '
            '(${trend.slopePerDay!.toStringAsFixed(2)} mmHg per day).',
        sampleCount: trend.sampleCount,
        limitation: trend.direction == TrendDirection.stable
            ? 'The variation stayed within the range considered normal '
                'day-to-day fluctuation.'
            : 'A mathematical trend is not a clinical conclusion.',
      ),
    );
  }

  // The latest reading versus recent readings.
  final latest = current.latest;
  if (latest != null && systolic.count >= 4) {
    final deviation = latest.value - systolic.median;
    if (deviation.abs() >= 15) {
      insights.add(
        Insight(
          id: 'bp.latest-outlier',
          kind: InsightKind.outlier,
          title: 'Latest reading differs from your recent readings',
          body:
              'Your latest systolic reading of '
              '${latest.value.toStringAsFixed(0)} mmHg is '
              '${deviation.abs().toStringAsFixed(0)} mmHg away from the median '
              'of the last ${systolic.count} readings. Consider repeating the '
              'measurement using the recommended technique.',
          sampleCount: systolic.count,
          limitation:
              'A single unusual reading may reflect technique, timing, or '
              'everyday circumstances rather than a change in your health.',
        ),
      );
    }
  }

  // Guideline distribution, stated with its denominator.
  final normalShare = current.shareOf(BpCategory.normal);
  if (current.readingCount >= 5) {
    insights.add(
      Insight(
        id: 'bp.distribution',
        kind: InsightKind.comparison,
        title: 'Guideline distribution',
        body:
            '${(normalShare * 100).round()}% of your '
            '${current.readingCount} recorded readings were below 120/80, '
            'classified as Normal under the ${current.guideline.name} '
            'guideline.',
        sampleCount: current.readingCount,
        limitation:
            'A small number of readings does not represent your overall '
            'clinical condition.',
      ),
    );
  }

  if (diastolic != null && diastolic.count != systolic.count) {
    insights.add(
      const Insight(
        id: 'bp.partial',
        kind: InsightKind.sparsity,
        title: 'Some readings have no diastolic value',
        body:
            'Averages are computed separately for systolic and diastolic '
            'readings, so they may be based on different numbers of '
            'measurements.',
      ),
    );
  }

  return insights;
}

/// Builds the insights for the weight analytics screen.
List<Insight> weightInsights({
  required WeightPeriodSummary current,
  WeightPeriodSummary? previous,
}) {
  final insights = <Insight>[];
  final stats = current.stats;

  if (stats == null || stats.count == 0) {
    insights.add(
      const Insight(
        id: 'weight.no-data',
        kind: InsightKind.sparsity,
        title: 'No weigh-ins yet',
        body: 'Record a weight to start building your trend.',
      ),
    );
    return insights;
  }

  if (previous != null && previous.stats != null) {
    final change = Change.between(previous.stats!.mean, stats.mean);
    if (change != null && change.absolute.abs() >= 0.1) {
      insights.add(
        Insight(
          id: 'weight.comparison',
          kind: InsightKind.comparison,
          title: change.absolute < 0 ? 'Weight is down' : 'Weight is up',
          body:
              'Your average weight changed by '
              '${change.absolute.abs().toStringAsFixed(1)} kg compared with '
              'the previous ${previous.period.dayCount}-day period '
              '(${stats.mean.toStringAsFixed(1)} kg versus '
              '${previous.stats!.mean.toStringAsFixed(1)} kg).',
          sampleCount: stats.count,
          limitation:
              'Daily weight fluctuates with hydration, sleep, and meal '
              'timing. A difference of a few tenths of a kilogram is normal '
              'variation.',
        ),
      );
    }
  }

  insights.add(
    Insight(
      id: 'weight.consistency',
      kind: InsightKind.consistency,
      title: 'Recording consistency',
      body:
          'You weighed in on ${current.loggedDays} of the last '
          '${current.totalDays} days '
          '(${(current.completeness * 100).round()}%).',
      sampleCount: stats.count,
    ),
  );

  final trend = current.trend;
  if (trend.direction == TrendDirection.insufficientData) {
    insights.add(
      Insight(
        id: 'weight.trend',
        kind: InsightKind.sparsity,
        title: 'Not enough weigh-ins for a reliable trend',
        body: trend.limitation ??
            'There are not enough measurements to calculate a reliable trend.',
        sampleCount: trend.sampleCount,
      ),
    );
  } else {
    final pace = current.weeklyPace;
    insights.add(
      Insight(
        id: 'weight.trend',
        kind: InsightKind.change,
        title: switch (trend.direction) {
          TrendDirection.increasing => 'Weight is trending up',
          TrendDirection.decreasing => 'Weight is trending down',
          TrendDirection.stable => 'Weight is stable',
          TrendDirection.insufficientData => 'Trend unavailable',
        },
        body: pace == null
            ? 'Across ${trend.sampleCount} days of readings the estimated '
                'change is ${trend.totalChange!.toStringAsFixed(1)} kg.'
            : 'Across ${trend.sampleCount} days of readings the estimated '
                'change is ${trend.totalChange!.toStringAsFixed(1)} kg '
                '(${pace.toStringAsFixed(2)} kg per week).',
        sampleCount: trend.sampleCount,
        limitation:
            'This describes the recorded data only. It is not advice about '
            'what your weight should be.',
      ),
    );
  }

  final bodyFatChange = current.bodyFatChange;
  if (current.bodyFatLatest != null && bodyFatChange != null) {
    insights.add(
      Insight(
        id: 'weight.body-fat',
        kind: InsightKind.comparison,
        title: 'Body fat ratio',
        body:
            'Your latest body-fat reading is '
            '${current.bodyFatLatest!.toStringAsFixed(1)}%, '
            '${bodyFatChange.absolute.abs().toStringAsFixed(1)} percentage '
            'points ${bodyFatChange.absolute < 0 ? 'lower' : 'higher'} than '
            'the previous period.',
        sampleCount: stats.count,
        limitation:
            'Body-fat readings depend on the device and method used, so they '
            'are comparable within a method rather than across methods.',
      ),
    );
  }

  return insights;
}

/// Builds the observation shown on the home dashboard.
///
/// One observation, chosen for usefulness: a comparison when a previous
/// period exists, otherwise a consistency statement.
Insight dashboardInsight({
  required BpPeriodSummary current,
  BpPeriodSummary? previous,
}) {
  final insights = bloodPressureInsights(current: current, previous: previous);
  for (final insight in insights) {
    if (insight.kind == InsightKind.comparison &&
        insight.id == 'bp.systolic-comparison') {
      return insight;
    }
  }
  for (final insight in insights) {
    if (insight.kind == InsightKind.consistency) return insight;
  }
  return insights.first;
}

/// A short, human label for a period, used in insight copy.
String periodLabel(DateTime start, DateTime end) =>
    '${shortDateLabel(start)} – ${shortDateLabel(end)}';
