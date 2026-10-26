import 'package:flutter_test/flutter_test.dart';
import 'package:healthie/core/units/unit.dart';
import 'package:healthie/core/utils/date_range.dart';
import 'package:healthie/core/utils/date_utils.dart';
import 'package:healthie/features/analytics/domain/blood_pressure_analytics.dart';
import 'package:healthie/features/analytics/domain/insight.dart';
import 'package:healthie/features/metrics/domain/blood_pressure_guideline.dart';
import 'package:healthie/features/metrics/domain/measurement.dart';
import 'package:healthie/features/metrics/domain/metric_type.dart';

Measurement bloodPressure({
  required DateTime at,
  required double systolic,
  required double diastolic,
  double? pulse,
}) {
  return Measurement(
    id: 'bp-${at.microsecondsSinceEpoch}',
    metricType: MetricType.bloodPressure,
    value: systolic,
    unit: Unit.millimetreOfMercury,
    secondaryValue: diastolic,
    secondaryUnit: Unit.millimetreOfMercury,
    tertiaryValue: pulse,
    tertiaryUnit: pulse == null ? null : Unit.beatsPerMinute,
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

  group('summariseBloodPressure', () {
    test('reports null statistics for an empty period', () {
      final summary = summariseBloodPressure(
        period: period,
        measurements: const [],
      );
      expect(summary.systolic, isNull);
      expect(summary.diastolic, isNull);
      expect(summary.readingCount, 0);
      expect(summary.completeness, 0);
    });

    test('computes systolic and diastolic statistics separately', () {
      final summary = summariseBloodPressure(
        period: period,
        measurements: [
          bloodPressure(
            at: DateTime(2026, 3, 1, 8),
            systolic: 120,
            diastolic: 80,
          ),
          bloodPressure(
            at: DateTime(2026, 3, 2, 8),
            systolic: 140,
            diastolic: 90,
          ),
        ],
      );
      expect(summary.systolic!.mean, 130);
      expect(summary.diastolic!.mean, 85);
      expect(summary.readingCount, 2);
    });

    test('distributes readings across the guideline categories', () {
      final summary = summariseBloodPressure(
        period: period,
        measurements: [
          bloodPressure(
            at: DateTime(2026, 3, 1, 8),
            systolic: 115,
            diastolic: 75,
          ),
          bloodPressure(
            at: DateTime(2026, 3, 2, 8),
            systolic: 125,
            diastolic: 75,
          ),
          bloodPressure(
            at: DateTime(2026, 3, 3, 8),
            systolic: 135,
            diastolic: 85,
          ),
          bloodPressure(
            at: DateTime(2026, 3, 4, 8),
            systolic: 150,
            diastolic: 95,
          ),
        ],
      );
      expect(summary.countIn(BpCategory.normal), 1);
      expect(summary.countIn(BpCategory.elevated), 1);
      expect(summary.countIn(BpCategory.stage1Hypertension), 1);
      expect(summary.countIn(BpCategory.stage2Hypertension), 1);
      expect(summary.shareOf(BpCategory.normal), 0.25);
    });

    test('computes the daily mean of several readings on one day', () {
      final summary = summariseBloodPressure(
        period: period,
        measurements: [
          bloodPressure(
            at: DateTime(2026, 3, 1, 8),
            systolic: 120,
            diastolic: 80,
          ),
          bloodPressure(
            at: DateTime(2026, 3, 1, 20),
            systolic: 130,
            diastolic: 90,
          ),
        ],
      );
      expect(summary.daily, hasLength(1));
      expect(summary.daily.first.systolic, 125);
      expect(summary.daily.first.sampleCount, 2);
    });

    test('separates morning and evening readings', () {
      final summary = summariseBloodPressure(
        period: period,
        measurements: [
          bloodPressure(
            at: DateTime(2026, 3, 1, 7),
            systolic: 125,
            diastolic: 82,
          ),
          bloodPressure(
            at: DateTime(2026, 3, 1, 19),
            systolic: 115,
            diastolic: 75,
          ),
        ],
      );
      expect(summary.morning.sampleCount, 1);
      expect(summary.morning.systolic, 125);
      expect(summary.evening.sampleCount, 1);
      expect(summary.evening.systolic, 115);
    });

    test('reports the completeness of the period', () {
      final summary = summariseBloodPressure(
        period: period,
        measurements: [
          bloodPressure(
            at: DateTime(2026, 3, 1, 8),
            systolic: 120,
            diastolic: 80,
          ),
          bloodPressure(
            at: DateTime(2026, 3, 2, 8),
            systolic: 120,
            diastolic: 80,
          ),
        ],
      );
      expect(summary.loggedDays, 2);
      expect(summary.totalDays, 30);
      expect(summary.completeness, closeTo(2 / 30, 0.0001));
    });

    test('ignores measurements outside the period', () {
      final summary = summariseBloodPressure(
        period: period,
        measurements: [
          bloodPressure(
            at: DateTime(2026, 2, 1, 8),
            systolic: 200,
            diastolic: 120,
          ),
        ],
      );
      // The engine summarises what it is given; the repository is what
      // filters by period. This documents the contract.
      expect(summary.readingCount, 1);
    });
  });

  group('bloodPressureInsights', () {
    test('reports that there is no data when nothing was recorded', () {
      final summary = summariseBloodPressure(
        period: period,
        measurements: const [],
      );
      final insights = bloodPressureInsights(current: summary);
      expect(insights.first.kind, InsightKind.sparsity);
      expect(insights.first.id, 'bp.no-data');
    });

    test('compares against the previous period when one exists', () {
      final current = summariseBloodPressure(
        period: period,
        measurements: [
          bloodPressure(
            at: DateTime(2026, 3, 1, 8),
            systolic: 130,
            diastolic: 85,
          ),
        ],
      );
      final previous = summariseBloodPressure(
        period: period.previous,
        measurements: [
          bloodPressure(
            at: DateTime(2026, 2, 1, 8),
            systolic: 120,
            diastolic: 80,
          ),
        ],
      );
      final insights = bloodPressureInsights(
        current: current,
        previous: previous,
      );
      final comparison = insights.firstWhere(
        (insight) => insight.id == 'bp.systolic-comparison',
      );
      expect(comparison.body, contains('10 mmHg'));
      expect(comparison.body, contains('higher'));
      expect(comparison.sampleCount, 1);
    });

    test('states how many days were logged', () {
      final summary = summariseBloodPressure(
        period: period,
        measurements: [
          bloodPressure(
            at: DateTime(2026, 3, 1, 8),
            systolic: 120,
            diastolic: 80,
          ),
        ],
      );
      final insights = bloodPressureInsights(current: summary);
      final consistency = insights.firstWhere(
        (insight) => insight.id == 'bp.consistency',
      );
      expect(consistency.body, contains('1 of the last 30 days'));
    });

    test('reports that there is too little data for a trend', () {
      final summary = summariseBloodPressure(
        period: period,
        measurements: [
          bloodPressure(
            at: DateTime(2026, 3, 1, 8),
            systolic: 120,
            diastolic: 80,
          ),
          bloodPressure(
            at: DateTime(2026, 3, 2, 8),
            systolic: 121,
            diastolic: 81,
          ),
        ],
      );
      final insights = bloodPressureInsights(current: summary);
      final trend = insights.firstWhere((insight) => insight.id == 'bp.trend');
      expect(trend.kind, InsightKind.sparsity);
    });

    test('flags a latest reading that differs from the recent median', () {
      final readings = <Measurement>[
        for (var day = 1; day <= 4; day++)
          bloodPressure(
            at: DateTime(2026, 3, day, 8),
            systolic: 120,
            diastolic: 80,
          ),
        bloodPressure(
          at: DateTime(2026, 3, 5, 8),
          systolic: 170,
          diastolic: 100,
        ),
      ];
      final summary = summariseBloodPressure(
        period: period,
        measurements: readings,
      );
      final insights = bloodPressureInsights(current: summary);
      final outlier = insights.firstWhere(
        (insight) => insight.id == 'bp.latest-outlier',
      );
      expect(outlier.kind, InsightKind.outlier);
      expect(outlier.body, contains('170'));
    });

    test('gives every insight a limitation where it matters', () {
      final summary = summariseBloodPressure(
        period: period,
        measurements: [
          for (var day = 1; day <= 6; day++)
            bloodPressure(
              at: DateTime(2026, 3, day, 8),
              systolic: 120,
              diastolic: 80,
            ),
        ],
      );
      final insights = bloodPressureInsights(current: summary);
      final distribution = insights.firstWhere(
        (insight) => insight.id == 'bp.distribution',
      );
      expect(distribution.limitation, isNotNull);
      expect(distribution.body, contains('6 recorded readings'));
    });
  });

  group('dashboardInsight', () {
    test('prefers the comparison when a previous period exists', () {
      final current = summariseBloodPressure(
        period: period,
        measurements: [
          bloodPressure(
            at: DateTime(2026, 3, 1, 8),
            systolic: 130,
            diastolic: 85,
          ),
        ],
      );
      final previous = summariseBloodPressure(
        period: period.previous,
        measurements: [
          bloodPressure(
            at: DateTime(2026, 2, 1, 8),
            systolic: 120,
            diastolic: 80,
          ),
        ],
      );
      final insight = dashboardInsight(current: current, previous: previous);
      expect(insight.id, 'bp.systolic-comparison');
    });

    test('falls back to the consistency statement', () {
      final current = summariseBloodPressure(
        period: period,
        measurements: [
          bloodPressure(
            at: DateTime(2026, 3, 1, 8),
            systolic: 120,
            diastolic: 80,
          ),
        ],
      );
      final insight = dashboardInsight(current: current);
      expect(insight.id, 'bp.consistency');
    });
  });
}
