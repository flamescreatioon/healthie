# Chart Recipes (fl_chart 1.2.0)

All examples target fl_chart 1.2.0. Apply the `dataviz` skill's palette and axis
rules alongside these.

## Trend line — "how has my weight changed?"

```dart
class WeightTrendChart extends StatelessWidget {
  const WeightTrendChart({
    super.key,
    required this.points,        // List<({DateTime at, double value})>
    required this.unitSymbol,
    required this.accent,
  });

  final List<({DateTime at, double value})> points;
  final String unitSymbol;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const _EmptyChart(message: 'No weight entries yet');
    }

    final sorted = [...points]..sort((a, b) => a.at.compareTo(b.at));
    final minX = sorted.first.at.millisecondsSinceEpoch.toDouble();
    final maxX = sorted.last.at.millisecondsSinceEpoch.toDouble();
    final span = (maxX - minX).abs() < 1 ? 1.0 : maxX - minX;

    final spots = sorted
        .map((p) => FlSpot(
              (p.at.millisecondsSinceEpoch.toDouble() - minX) / span,
              p.value,
            ))
        .toList();

    final values = sorted.map((p) => p.value);
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final padY = ((maxY - minY) * 0.15).abs() < 1 ? 1.0 : (maxY - minY) * 0.15;

    // Sparse data: show discrete points rather than a continuous line.
    final isSparse = sorted.length < 8;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: 1,
        minY: minY - padY,
        maxY: maxY + padY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY - minY) / 4,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: (maxY - minY) / 4,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(1),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 0.25,
              getTitlesWidget: (value, meta) {
                final date = DateTime.fromMillisecondsSinceEpoch(
                  (minX + value * span).round(),
                );
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    DateFormat.MMMd().format(date),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots.map((s) {
              final date = DateTime.fromMillisecondsSinceEpoch(
                (minX + s.x * span).round(),
              );
              return LineTooltipItem(
                '${s.y.toStringAsFixed(1)} $unitSymbol\n',
                const TextStyle(fontWeight: FontWeight.w600),
                children: [
                  TextSpan(
                    text: DateFormat.yMMMd().format(date),
                    style: const TextStyle(fontWeight: FontWeight.normal),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: accent,
            barWidth: 2.5,
            dotData: FlDotData(
              show: isSparse,
              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                radius: 3.5,
                color: accent,
                strokeWidth: 2,
                strokeColor: Theme.of(context).colorScheme.surface,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  accent.withValues(alpha: 0.22),
                  accent.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

## Daily bars — "how much each day this week?"

```dart
class DailyStepsChart extends StatelessWidget {
  const DailyStepsChart({
    super.key,
    required this.dailyCounts,   // List<({DateTime day, int count})>
    required this.accent,
    required this.goal,
  });

  final List<({DateTime day, int count})> dailyCounts;
  final Color accent;
  final int? goal;

  @override
  Widget build(BuildContext context) {
    if (dailyCounts.isEmpty) {
      return const _EmptyChart(message: 'No steps recorded yet');
    }

    final maxCount = dailyCounts.map((d) => d.count).reduce((a, b) => a > b ? a : b);
    final maxY = goal != null && goal! > maxCount ? goal!.toDouble() : maxCount.toDouble();

    return BarChart(
      BarChartData(
        maxY: maxY * 1.15,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= dailyCounts.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    DateFormat.E().format(dailyCounts[index].day),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final day = dailyCounts[group.x].day;
              return BarTooltipItem(
                '${rod.toY.toInt()} steps\n${DateFormat.MMMEd().format(day)}',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              );
            },
          ),
        ),
        barGroups: [
          for (var i = 0; i < dailyCounts.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: dailyCounts[i].count.toDouble(),
                  color: accent,
                  width: 14,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
```

A goal line can be overlaid with `extraLinesData: ExtraLinesData(horizontalLines: [...])`.

## Sparkline — inside a stat tile

```dart
class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return const SizedBox.shrink();
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final span = (maxV - minV).abs() < 1e-9 ? 1.0 : maxV - minV;

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < values.length; i++)
                FlSpot(i / (values.length - 1), values[i]),
            ],
            isCurved: true,
            curveSmoothness: 0.2,
            color: color,
            barWidth: 1.8,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

## Stat tile

```dart
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    this.comparison,
    this.sparklineValues,
    this.accent,
    this.onTap,
  });

  final String label;
  final String value;
  final String unit;
  final String? comparison;
  final List<double>? sparklineValues;
  final Color? accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelMedium),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(value, style: theme.textTheme.headlineMedium),
                  const SizedBox(width: 4),
                  Text(unit, style: theme.textTheme.bodySmall),
                ],
              ),
              if (comparison != null) ...[
                const SizedBox(height: 4),
                Text(comparison!, style: theme.textTheme.bodySmall),
              ],
              if (sparklineValues != null && sparklineValues!.length > 1) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 32,
                  child: Sparkline(
                    values: sparklineValues!,
                    color: accent ?? theme.colorScheme.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
```

## Goal meter

```dart
class GoalMeter extends StatelessWidget {
  const GoalMeter({
    super.key,
    required this.current,
    required this.goal,
    required this.unit,
    this.direction = GoalDirection.increase,
  });

  final double current;
  final double goal;
  final String unit;
  final GoalDirection direction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Direction-aware: a loss goal and a gain goal both progress toward the goal.
    final raw = direction == GoalDirection.increase
        ? current / goal
        : (goal - current) / goal;
    final progress = raw.clamp(0.0, 1.0);
    final reached = direction == GoalDirection.increase ? current >= goal : current <= goal;

    final remaining = direction == GoalDirection.increase
        ? goal - current
        : current - goal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${current.toStringAsFixed(1)} $unit', style: theme.textTheme.titleMedium),
            Text('Goal ${goal.toStringAsFixed(1)} $unit', style: theme.textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          reached
              ? 'Goal reached'
              : '${remaining.abs().toStringAsFixed(1)} $unit to go',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
```

## Empty state

```dart
class _EmptyChart extends StatelessWidget {
  const _EmptyChart({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 8),
            Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
```

## Downsampling

Plot at most ~200 points. Aggregate before rendering:

```dart
List<({DateTime day, double value})> downsampleToDaily(
  List<({DateTime at, double value})> points,
) {
  final byDay = <DateTime, List<double>>{};
  for (final p in points) {
    final day = DateTime(p.at.year, p.at.month, p.at.day);
    byDay.putIfAbsent(day, () => []).add(p.value);
  }
  final entries = byDay.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  return entries
      .map((e) => (day: e.key, value: e.value.reduce((a, b) => a + b) / e.value.length))
      .toList();
}
```
