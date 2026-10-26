import 'package:flutter_test/flutter_test.dart';
import 'package:healthie/core/units/unit.dart';
import 'package:healthie/core/utils/date_range.dart';
import 'package:healthie/core/utils/date_utils.dart';
import 'package:healthie/features/analytics/domain/insight.dart';
import 'package:healthie/features/analytics/domain/weight_analytics.dart';
import 'package:healthie/features/metrics/domain/measurement.dart';
import 'package:healthie/features/metrics/domain/metric_type.dart';

Measurement weight({
  required DateTime at,
  required double kilograms,
  double? bodyFat,
  double? waist,
}) {
  return Measurement(
    id: 'w-${at.microsecondsSinceEpoch}',
    metricType: MetricType.weight,
    value: kilograms,
    unit: Unit.kilogram,
    secondaryValue: bodyFat,
    secondaryUnit: bodyFat == null ? null : Unit.percent,
    tertiaryValue: waist,
    tertiaryUnit: waist == null ? null : Unit.centimetre,
    recordedAt: at.toUtc(),
    localDay: startOfLocalDay(at),
    createdAt: at.toUtc(),
    updatedAt: at.toUtc(),
  );
}

void main() {
  final period = DateRange(
    start: DateTime(2026, 3, 1),
    end: DateTime(2026, 3, 31),
  );

  group('summariseWeight', () {
    test('reports null statistics for an empty period', () {
      final summary = summariseWeight(
        period: period,
        measurements: const [],
      );
      expect(summary.stats, isNull);
      expect(summary.latest, isNull);
      expect(summary.daily, isEmpty);
    });

    test('computes the mean over all weigh-ins', () {
      final summary = summariseWeight(
        period: period,
        measurements: [
          weight(at: DateTime(2026, 3, 1, 7), kilograms: 70),
          weight(at: DateTime(2026, 3, 2, 7), kilograms: 69),
        ],
      );
      expect(summary.stats!.mean, 69.5);
      expect(summary.baseline, 69.5);
      expect(summary.startingWeight, 70);
    });

    test('averages several weigh-ins within one day', () {
      final summary = summariseWeight(
        period: period,
        measurements: [
          weight(at: DateTime(2026, 3, 1, 7), kilograms: 70),
          weight(at: DateTime(2026, 3, 1, 19), kilograms: 69),
        ],
      );
      expect(summary.daily, hasLength(1));
      expect(summary.daily.first.weight, 69.5);
      expect(summary.daily.first.sampleCount, 2);
    });

    test('leaves the moving average empty until the window is complete', () {
      final summary = summariseWeight(
        period: period,
        measurements: [
          for (var day = 1; day <= 10; day++)
            weight(at: DateTime(2026, 3, day, 7), kilograms: 70 - day * 0.1),
        ],
      );
      expect(summary.daily.first.smoothing, isNull);
      expect(summary.daily[6].smoothing, isNotNull);
    });

    test('compares against the previous period', () {
      final summary = summariseWeight(
        period: period,
        measurements: [
          weight(at: DateTime(2026, 3, 1, 7), kilograms: 68),
        ],
        previousPeriodMeasurements: [
          weight(at: DateTime(2026, 2, 1, 7), kilograms: 70),
        ],
      );
      expect(summary.changeFromPrevious!.absolute, -2);
    });

    test('reports the weekly pace from the period change', () {
      final summary = summariseWeight(
        period: period,
        measurements: [
          weight(at: DateTime(2026, 3, 1, 7), kilograms: 68),
        ],
        previousPeriodMeasurements: [
          weight(at: DateTime(2026, 2, 1, 7), kilograms: 70),
        ],
      );
      // Two kilograms over thirty days is roughly half a kilogram a week.
      expect(summary.weeklyPace, closeTo(-2 * 7 / 30, 0.0001));
    });

    test('tracks the latest body-fat reading', () {
      final summary = summariseWeight(
        period: period,
        measurements: [
          weight(
            at: DateTime(2026, 3, 1, 7),
            kilograms: 69,
            bodyFat: 22.1,
          ),
          weight(
            at: DateTime(2026, 3, 2, 7),
            kilograms: 68.9,
            bodyFat: 21.4,
          ),
        ],
      );
      expect(summary.bodyFatLatest, 21.4);
    });

    test('reports the completeness of the period', () {
      final summary = summariseWeight(
        period: period,
        measurements: [
          weight(at: DateTime(2026, 3, 1, 7), kilograms: 69),
          weight(at: DateTime(2026, 3, 2, 7), kilograms: 68.9),
        ],
      );
      expect(summary.loggedDays, 2);
      expect(summary.totalDays, 30);
    });
  });

  group('computeGoalProgress', () {
    test('reports no progress when the start equals the target', () {
      final progress = computeGoalProgress(
        target: 66,
        current: 66,
        start: 66,
      )!;
      expect(progress.percentAchieved, 1);
      expect(progress.remaining, 0);
    });

    test('measures progress towards a lower target', () {
      final progress = computeGoalProgress(
        target: 66,
        current: 68.5,
        start: 71,
      )!;
      expect(progress.percentAchieved, closeTo(0.5, 0.0001));
      expect(progress.remaining, closeTo(2.5, 0.0001));
      expect(progress.hasPassedTarget, isFalse);
    });

    test('measures progress towards a higher target', () {
      final progress = computeGoalProgress(
        target: 80,
        current: 75,
        start: 70,
      )!;
      expect(progress.percentAchieved, closeTo(0.5, 0.0001));
    });

    test('clamps progress when the target is overshot', () {
      final progress = computeGoalProgress(
        target: 66,
        current: 64,
        start: 71,
      )!;
      expect(progress.percentAchieved, 1);
      expect(progress.remaining, 0);
      expect(progress.hasPassedTarget, isTrue);
    });

    test('reports no progress when the weight has moved the wrong way', () {
      final progress = computeGoalProgress(
        target: 66,
        current: 72,
        start: 71,
      )!;
      expect(progress.percentAchieved, 0);
    });
  });

  group('weightInsights', () {
    test('reports that there is no data when nothing was recorded', () {
      final summary = summariseWeight(
        period: period,
        measurements: const [],
      );
      final insights = weightInsights(current: summary);
      expect(insights.first.id, 'weight.no-data');
    });

    test('compares against the previous period', () {
      final summary = summariseWeight(
        period: period,
        measurements: [
          weight(at: DateTime(2026, 3, 1, 7), kilograms: 68),
        ],
        previousPeriodMeasurements: [
          weight(at: DateTime(2026, 2, 1, 7), kilograms: 70),
        ],
      );
      final insights = weightInsights(
        current: summary,
        previous: summariseWeight(
          period: period.previous,
          measurements: [
            weight(at: DateTime(2026, 2, 1, 7), kilograms: 70),
          ],
        ),
      );
      final comparison = insights.firstWhere(
        (insight) => insight.id == 'weight.comparison',
      );
      expect(comparison.body, contains('2.0 kg'));
      expect(comparison.limitation, isNotNull);
    });

    test('states how many days were logged', () {
      final summary = summariseWeight(
        period: period,
        measurements: [
          weight(at: DateTime(2026, 3, 1, 7), kilograms: 68),
        ],
      );
      final insights = weightInsights(current: summary);
      final consistency = insights.firstWhere(
        (insight) => insight.id == 'weight.consistency',
      );
      expect(consistency.body, contains('1 of the last 30 days'));
    });

    test('does not present a change as good or bad', () {
      final summary = summariseWeight(
        period: period,
        measurements: [
          weight(at: DateTime(2026, 3, 1, 7), kilograms: 68),
        ],
        previousPeriodMeasurements: [
          weight(at: DateTime(2026, 2, 1, 7), kilograms: 70),
        ],
      );
      final insights = weightInsights(
        current: summary,
        previous: summariseWeight(
          period: period.previous,
          measurements: [
            weight(at: DateTime(2026, 2, 1, 7), kilograms: 70),
          ],
        ),
      );
      final comparison = insights.firstWhere(
        (insight) => insight.id == 'weight.comparison',
      );
      expect(comparison.title, 'Weight is down');
      expect(comparison.body.toLowerCase(), isNot(contains('great')));
      expect(comparison.body.toLowerCase(), isNot(contains('bad')));
    });
  });
}
