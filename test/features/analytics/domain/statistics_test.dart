import 'package:flutter_test/flutter_test.dart';
import 'package:healthie/features/analytics/domain/statistics.dart';
import 'package:healthie/features/analytics/domain/trend.dart';

void main() {
  group('DescriptiveStats', () {
    test('returns null for an empty dataset', () {
      expect(DescriptiveStats.from(const []), isNull);
    });

    test('computes the mean of a single value', () {
      final stats = DescriptiveStats.from(const [120])!;
      expect(stats.count, 1);
      expect(stats.mean, 120);
      expect(stats.median, 120);
      expect(stats.min, 120);
      expect(stats.max, 120);
    });

    test('computes the mean of several values', () {
      final stats = DescriptiveStats.from(const [110, 120, 130])!;
      expect(stats.mean, 120);
    });

    test('computes the median of an odd number of values', () {
      final stats = DescriptiveStats.from(const [110, 120, 130, 140, 150])!;
      expect(stats.median, 130);
    });

    test('computes the median of an even number of values', () {
      final stats = DescriptiveStats.from(const [110, 120, 130, 140])!;
      expect(stats.median, 125);
    });

    test('reports the minimum and maximum', () {
      final stats = DescriptiveStats.from(const [110, 120, 130])!;
      expect(stats.min, 110);
      expect(stats.max, 130);
    });

    test('has no standard deviation for a single reading', () {
      final stats = DescriptiveStats.from(const [120])!;
      expect(stats.standardDeviation, isNull);
    });

    test('computes the sample standard deviation', () {
      final stats = DescriptiveStats.from(const [2, 4, 4, 4, 5, 5, 7, 9])!;
      expect(stats.standardDeviation, closeTo(2.13809, 0.0001));
    });

    test('ignores the order of the input', () {
      final ascending = DescriptiveStats.from(const [110, 120, 130])!;
      final descending = DescriptiveStats.from(const [130, 120, 110])!;
      expect(ascending.mean, descending.mean);
      expect(ascending.median, descending.median);
    });
  });

  group('movingAverage', () {
    test('leaves the first positions empty until the window is complete', () {
      final result = movingAverage(const [1, 2, 3, 4, 5], 3);
      expect(result[0], isNull);
      expect(result[1], isNull);
      expect(result[2], 2);
      expect(result[3], 3);
      expect(result[4], 4);
    });

    test('does not average across a gap', () {
      final result = movingAverage(const [1, 2, null, 4, 5], 2);
      expect(result[0], isNull);
      expect(result[1], 1.5);
      expect(result[2], isNull);
      expect(result[3], isNull);
      expect(result[4], 4.5);
    });

    test('a window of one returns the values unchanged', () {
      final result = movingAverage(const [1, 2, 3], 1);
      expect(result, [1, 2, 3]);
    });
  });

  group('aggregateByDay', () {
    test('averages the readings within one local day', () {
      final points = aggregateByDay([
        TimedValue(at: DateTime(2026, 3, 10, 8), value: 120),
        TimedValue(at: DateTime(2026, 3, 10, 20), value: 130),
      ]);
      expect(points, hasLength(1));
      expect(points.first.value, 125);
      expect(points.first.sampleCount, 2);
    });

    test('keeps separate days separate', () {
      final points = aggregateByDay([
        TimedValue(at: DateTime(2026, 3, 10, 8), value: 120),
        TimedValue(at: DateTime(2026, 3, 11, 8), value: 130),
      ]);
      expect(points, hasLength(2));
    });
  });

  group('Change', () {
    test('computes the absolute change', () {
      final change = Change.between(100, 95)!;
      expect(change.absolute, -5);
      expect(change.relativePercent, closeTo(-5, 0.0001));
    });

    test('reports no percentage change when the baseline is zero', () {
      final change = Change.between(0, 10)!;
      expect(change.absolute, 10);
      expect(change.relative, isNull);
      expect(change.relativePercent, isNull);
    });

    test('is null when either value is missing', () {
      expect(Change.between(null, 10), isNull);
      expect(Change.between(10, null), isNull);
    });
  });

  group('analyseTrend', () {
    test('reports insufficient data for no readings', () {
      final result = analyseTrend(const [], meaningfulChange: 1);
      expect(result.direction, TrendDirection.insufficientData);
      expect(result.limitation, isNotNull);
    });

    test('reports insufficient data for a single reading', () {
      final result = analyseTrend(
        [TimedValue(at: DateTime(2026, 3, 10), value: 120)],
        meaningfulChange: 1,
      );
      expect(result.direction, TrendDirection.insufficientData);
    });

    test('does not declare a trend from two readings', () {
      final result = analyseTrend(
        [
          TimedValue(at: DateTime(2026, 3, 1), value: 120),
          TimedValue(at: DateTime(2026, 3, 10), value: 140),
        ],
        meaningfulChange: 1,
      );
      expect(result.direction, TrendDirection.insufficientData);
      expect(result.limitation, contains('Two points'));
    });

    test('detects a rising trend', () {
      final result = analyseTrend(
        [
          TimedValue(at: DateTime(2026, 3, 1), value: 120),
          TimedValue(at: DateTime(2026, 3, 5), value: 128),
          TimedValue(at: DateTime(2026, 3, 10), value: 136),
          TimedValue(at: DateTime(2026, 3, 15), value: 144),
        ],
        meaningfulChange: 5,
      );
      expect(result.direction, TrendDirection.increasing);
      // The Theil-Sen estimator is the median of the pairwise slopes, which
      // for this series is (1.6 + 1.714) / 2.
      expect(result.slopePerDay, closeTo(1.657142857, 0.000001));
    });

    test('detects a falling trend', () {
      final result = analyseTrend(
        [
          TimedValue(at: DateTime(2026, 3, 1), value: 144),
          TimedValue(at: DateTime(2026, 3, 5), value: 136),
          TimedValue(at: DateTime(2026, 3, 10), value: 128),
          TimedValue(at: DateTime(2026, 3, 15), value: 120),
        ],
        meaningfulChange: 5,
      );
      expect(result.direction, TrendDirection.decreasing);
    });

    test('reports a stable series when the change is below the threshold', () {
      final result = analyseTrend(
        [
          TimedValue(at: DateTime(2026, 3, 1), value: 120),
          TimedValue(at: DateTime(2026, 3, 5), value: 121),
          TimedValue(at: DateTime(2026, 3, 10), value: 120),
          TimedValue(at: DateTime(2026, 3, 15), value: 121),
        ],
        meaningfulChange: 5,
      );
      expect(result.direction, TrendDirection.stable);
    });

    test('is robust to a single outlying reading', () {
      final result = analyseTrend(
        [
          TimedValue(at: DateTime(2026, 3, 1), value: 120),
          TimedValue(at: DateTime(2026, 3, 5), value: 121),
          TimedValue(at: DateTime(2026, 3, 10), value: 190),
          TimedValue(at: DateTime(2026, 3, 15), value: 122),
          TimedValue(at: DateTime(2026, 3, 20), value: 123),
        ],
        meaningfulChange: 5,
      );
      // The Theil-Sen estimator ignores the outlier; a least-squares fit
      // would be dragged upwards by it.
      expect(result.direction, TrendDirection.stable);
    });

    test('handles unevenly spaced readings', () {
      final result = analyseTrend(
        [
          TimedValue(at: DateTime(2026, 3, 1), value: 120),
          TimedValue(at: DateTime(2026, 3, 2), value: 121),
          TimedValue(at: DateTime(2026, 3, 30), value: 130),
        ],
        meaningfulChange: 5,
      );
      expect(result.hasDirection, isTrue);
    });
  });
}
