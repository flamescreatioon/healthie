/// A time-series line chart with gaps for missing observations.
///
/// Health data is not evenly sampled. A line drawn straight through a week
/// with no readings would imply measurements that were never taken, so the
/// chart is drawn as one segment per contiguous run of data and the gap is
/// left visible.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';

/// One series on a [TrendChart].
class ChartSeries {
  const ChartSeries({
    required this.label,
    required this.values,
    required this.color,
    this.dashed = false,
    this.showDots = true,
    this.fill = false,
    this.showLastDot = true,
  });

  /// The series name, used in the legend and in tooltips.
  final String label;

  /// The values, indexed by x position. A null is a gap.
  final List<double?> values;

  /// The series colour.
  final Color color;

  /// Whether the line is dashed.
  final bool dashed;

  /// Whether the individual points are drawn.
  final bool showDots;

  /// Whether the area under the line is filled.
  final bool fill;

  /// Whether the most recent point gets a larger marker.
  final bool showLastDot;

  /// The series split into contiguous runs, so gaps stay visible.
  List<List<FlSpot>> get segments {
    final segments = <List<FlSpot>>[];
    var current = <FlSpot>[];
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      if (value == null) {
        if (current.isNotEmpty) segments.add(current);
        current = <FlSpot>[];
        continue;
      }
      current.add(FlSpot(i.toDouble(), value));
    }
    if (current.isNotEmpty) segments.add(current);
    return segments;
  }
}

/// A horizontal reference line on a [TrendChart].
class ReferenceLine {
  const ReferenceLine({
    required this.value,
    required this.label,
    required this.color,
    this.dashed = true,
  });

  /// The value the line sits at.
  final double value;

  /// A short label, e.g. `120/80 target`.
  final String label;

  /// The line colour.
  final Color color;

  /// Whether the line is dashed.
  final bool dashed;
}

/// An interactive time-series chart.
class TrendChart extends StatelessWidget {
  const TrendChart({
    required this.series,
    super.key,
    this.height = 220,
    this.minY,
    this.maxY,
    this.referenceLines = const [],
    this.leftTitleBuilder,
    this.bottomTitleBuilder,
    this.tooltipBuilder,
    this.padding = const EdgeInsets.fromLTRB(8, 16, 16, 8),
  });

  /// The series to draw.
  final List<ChartSeries> series;

  /// The chart's height.
  final double height;

  /// The lowest value on the y axis. Computed from the data when null.
  final double? minY;

  /// The highest value on the y axis. Computed from the data when null.
  final double? maxY;

  /// Reference lines, such as a clinical target.
  final List<ReferenceLine> referenceLines;

  /// Builds the y-axis label for a value.
  final String Function(double value)? leftTitleBuilder;

  /// Builds the x-axis label for a position.
  final String Function(double value)? bottomTitleBuilder;

  /// Builds the tooltip body for a touched spot.
  final List<TextSpan> Function(LineBarSpot spot)? tooltipBuilder;

  /// Padding around the chart.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allValues = [
      for (final s in series)
        for (final value in s.values)
          ?value,
    ];    if (allValues.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'No readings in this period',
            style: AppTypography.bodySmall
                .copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    var lowest = allValues.reduce((a, b) => a < b ? a : b);
    var highest = allValues.reduce((a, b) => a > b ? a : b);
    for (final line in referenceLines) {
      lowest = lowest < line.value ? lowest : line.value;
      highest = highest > line.value ? highest : line.value;
    }
    final span = (highest - lowest).abs() < 1 ? 1.0 : (highest - lowest);
    final resolvedMin = minY ?? lowest - span * 0.15;
    final resolvedMax = maxY ?? highest + span * 0.15;

    final totalPoints = allValues.length;
    final avg = totalPoints > 0
        ? (allValues.reduce((a, b) => a + b) / totalPoints).round()
        : 0;
    final seriesNames = series.map((s) => s.label).join(', ');
    final chartSemantics =
        'Trend chart for $seriesNames: $totalPoints readings, '
        'ranging from ${lowest.round()} to ${highest.round()}, average $avg.';

    return Semantics(
      label: chartSemantics,
      child: SizedBox(
        height: height,
        child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (series.first.values.length - 1).toDouble().clamp(
                0,
                double.infinity,
              ),
          minY: resolvedMin,
          maxY: resolvedMax,
          clipData: const FlClipData.all(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: span / 3,
            getDrawingHorizontalLine: (value) => FlLine(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
              strokeWidth: 1,
              dashArray: const [3, 3],
            ),
          ),
          borderData: FlBorderData(show: false),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              for (final line in referenceLines)
                HorizontalLine(
                  y: line.value,
                  color: line.color,
                  strokeWidth: 1.2,
                  dashArray: line.dashed ? const [4, 4] : null,
                ),
            ],
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                getTitlesWidget: (value, meta) {
                  final label = leftTitleBuilder?.call(value);
                  if (label == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      label,
                      textAlign: TextAlign.right,
                      style: AppTypography.labelMicro.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: _bottomInterval(series.first.values.length),
                getTitlesWidget: (value, meta) {
                  final label = bottomTitleBuilder?.call(value);
                  if (label == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      label,
                      style: AppTypography.labelMicro.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            handleBuiltInTouches: true,
            touchTooltipData: LineTouchTooltipData(
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipColor: (spot) => theme.colorScheme.inverseSurface,
              tooltipBorderRadius: BorderRadius.circular(AppRadius.control),
              tooltipPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              getTooltipItems: (spots) {
                if (spots.isEmpty) return const [];
                final spot = spots.first;
                final custom = tooltipBuilder?.call(spot);
                if (custom != null) {
                  return [
                    LineTooltipItem(
                      '',
                      AppTypography.bodySmall,
                      children: custom,
                    ),
                  ];
                }
                final match = series
                    .where((s) => s.color == spot.bar.color)
                    .cast<ChartSeries?>()
                    .firstWhere((s) => true, orElse: () => null);
                return [
                  LineTooltipItem(
                    '${match?.label ?? ''} ${spot.y.toStringAsFixed(1)}',
                    AppTypography.bodySmall.copyWith(
                      color: theme.colorScheme.onInverseSurface,
                    ),
                  ),
                ];
              },
            ),
          ),
          lineBarsData: [
            for (final s in series)
              for (final segment in s.segments)
                LineChartBarData(
                  spots: segment,
                  color: s.color,
                  barWidth: 2.4,
                  isCurved: false,
                  dashArray: s.dashed ? const [5, 4] : null,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: s.showDots && segment.length == 1,
                    getDotPainter: (spot, percent, bar, index) =>
                        FlDotCirclePainter(
                      radius: 3.5,
                      color: s.color,
                      strokeWidth: 2,
                      strokeColor: theme.colorScheme.surfaceContainerLowest,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: s.fill,
                    color: s.color.withValues(alpha: 0.14),
                  ),
                ),
          ],
        ),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      ),
    ),
  );
}

  static double _bottomInterval(int length) {
    if (length <= 8) return 1;
    if (length <= 20) return (length / 4).ceilToDouble();
    return (length / 5).ceilToDouble();
  }
}
