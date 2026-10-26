/// Small inline visuals: sparklines and distribution bars.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';

/// A tiny trend line for a stat card.
///
/// Deliberately drawn with a custom painter rather than a charting library:
/// a sparkline has no axes, no tooltip, and no interaction, and pulling in a
/// full chart to render one line is overkill.
class Sparkline extends StatelessWidget {
  const Sparkline({
    required this.values,
    required this.color,
    super.key,
    this.height = 40,
    this.showEndDot = true,
    this.fill = false,
  });

  /// The values, oldest first. Nulls are skipped.
  final List<double?> values;

  /// The line colour.
  final Color color;

  /// The height of the sparkline.
  final double height;

  /// Whether to draw a marker on the most recent point.
  final bool showEndDot;

  /// Whether to fill the area under the line.
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final points = values.whereType<double>().toList();
    if (points.length < 2) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            '—',
            style: AppTypography.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _SparklinePainter(
          values: points,
          color: color,
          showEndDot: showEndDot,
          fill: fill,
          background: Theme.of(context).colorScheme.surfaceContainerLowest,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({
    required this.values,
    required this.color,
    required this.showEndDot,
    required this.fill,
    required this.background,
  });

  final List<double> values;
  final Color color;
  final bool showEndDot;
  final bool fill;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    final lowest = values.reduce(math.min);
    final highest = values.reduce(math.max);
    final span = highest - lowest;
    final inset = showEndDot ? 4.0 : 2.0;

    double xAt(int index) =>
        values.length == 1 ? 0 : index / (values.length - 1) * size.width;

    double yAt(double value) {
      if (span == 0) return size.height / 2;
      final normalised = (value - lowest) / span;
      return size.height - inset - normalised * (size.height - inset * 2);
    }

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final point = Offset(xAt(i), yAt(values[i]));
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    if (fill) {
      final area = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
        area,
        Paint()..color = color.withValues(alpha: 0.12),
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    if (showEndDot) {
      canvas.drawCircle(
        Offset(xAt(values.length - 1), yAt(values.last)),
        3.5,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}

/// One segment of a [DistributionBar].
class DistributionSegment {
  const DistributionSegment({
    required this.label,
    required this.count,
    required this.color,
  });

  /// The segment's name.
  final String label;

  /// How many observations fall into this segment.
  final int count;

  /// The segment's colour.
  final Color color;
}

/// A stacked horizontal bar showing how observations are distributed.
class DistributionBar extends StatelessWidget {
  const DistributionBar({
    required this.segments,
    super.key,
    this.height = 14,
  });

  /// The segments, in display order.
  final List<DistributionSegment> segments;

  /// The bar's height.
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = segments.fold<int>(0, (sum, s) => sum + s.count);
    if (total == 0) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(height),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            for (final segment in segments)
              if (segment.count > 0)
                Expanded(
                  flex: segment.count,
                  child: Container(
                    color: segment.color,
                    height: height,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// A compact legend entry: a colour dot, a name, a share, and a count.
class DistributionLegendEntry extends StatelessWidget {
  const DistributionLegendEntry({
    required this.segment,
    required this.total,
    super.key,
    this.onTap,
  });

  /// The segment this entry describes.
  final DistributionSegment segment;

  /// The total number of observations, used to compute the share.
  final int total;

  /// An optional tap handler.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final share = total == 0 ? 0.0 : segment.count / total;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: segment.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  segment.label,
                  style: AppTypography.labelMedium
                      .copyWith(color: theme.colorScheme.onSurface),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${(share * 100).round()}%',
              style: AppTypography.headlineSmall
                  .copyWith(color: theme.colorScheme.onSurface),
            ),
            Text(
              '${segment.count} reading${segment.count == 1 ? '' : 's'}',
              style: AppTypography.bodySmall
                  .copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
