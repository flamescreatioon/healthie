/// The analytics screen.
///
/// Two views over the same stored data: a blood-pressure dashboard and a
/// weight dashboard. Every figure is computed from the records themselves,
/// and the denominators are always shown — a percentage without its count
/// is not information.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/units/unit.dart';
import '../../../core/utils/date_range.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/formatters/value_formatter.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_top_bar.dart';
import '../../../shared/widgets/charts/mini_charts.dart';
import '../../../shared/widgets/charts/trend_chart.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/selectors.dart';
import '../../../shared/widgets/states.dart';
import '../../metrics/domain/blood_pressure_guideline.dart';
import '../../metrics/domain/measurement.dart';
import '../../metrics/domain/metric_type.dart';
import '../../metrics/presentation/providers/measurement_providers.dart';
import '../../profile/presentation/providers/profile_providers.dart';
import '../domain/blood_pressure_analytics.dart';
import '../domain/insight.dart';
import '../domain/statistics.dart';
import '../domain/weight_analytics.dart';

/// Which metric the analytics screen is showing.
enum AnalyticsView {
  bloodPressure('Blood Pressure'),
  weight('Weight');

  const AnalyticsView(this.label);

  final String label;
}

/// The analytics hub.
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  AnalyticsView _view = AnalyticsView.bloodPressure;
  AnalysisRange _range = AnalysisRange.thirtyDays;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final period = _periodFor(_range);
    final previousPeriod = period.previous;

    final measurements = ref.watch(allMeasurementsProvider(period));
    final previousMeasurements = ref.watch(allMeasurementsProvider(previousPeriod));

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppTopBar(
              title: 'Biometric Analytics',
              icon: Icons.monitor_heart_rounded,
            ),
            Expanded(
              child: measurements.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: LoadingState(height: 400, lines: 4),
                ),
                error: (error, stack) => ErrorState(
                  message: "We couldn't load your analytics.",
                  onRetry: () => ref.invalidate(allMeasurementsProvider(period)),
                ),
                data: (data) => _AnalyticsBody(
                  view: _view,
                  range: _range,
                  period: period,
                  measurements: data,
                  previousMeasurements:
                      previousMeasurements.value ?? const <Measurement>[],
                  onViewChanged: (value) => setState(() => _view = value),
                  onRangeChanged: (value) => setState(() => _range = value),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static DateRange _periodFor(AnalysisRange range) {
    final now = DateTime.now();
    final today = startOfLocalDay(now);
    return DateRange(
      start: today.subtract(Duration(days: range.days - 1)),
      end: today.add(const Duration(days: 1)),
    );
  }
}

class _AnalyticsBody extends StatelessWidget {
  const _AnalyticsBody({
    required this.view,
    required this.range,
    required this.period,
    required this.measurements,
    required this.previousMeasurements,
    required this.onViewChanged,
    required this.onRangeChanged,
  });

  final AnalyticsView view;
  final AnalysisRange range;
  final DateRange period;
  final List<Measurement> measurements;
  final List<Measurement> previousMeasurements;
  final ValueChanged<AnalyticsView> onViewChanged;
  final ValueChanged<AnalysisRange> onRangeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Long-term trends and guideline distribution.',
                style: AppTypography.bodySmall
                    .copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.of(context).positive,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Local data',
              style: AppTypography.labelMicro.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SegmentedControl<AnalyticsView>(
          options: AnalyticsView.values,
          selected: view,
          onChanged: onViewChanged,
          labelBuilder: (option) => option.label,
        ),
        const SizedBox(height: 12),
        RangeSelector(selected: range, onChanged: onRangeChanged),
        const SizedBox(height: 16),
        if (view == AnalyticsView.bloodPressure)
          BloodPressureAnalyticsView(
            period: period,
            measurements: measurements,
            previousMeasurements: previousMeasurements,
          )
        else
          WeightAnalyticsView(
            period: period,
            measurements: measurements,
            previousMeasurements: previousMeasurements,
          ),
      ],
    );
  }
}

/// The blood-pressure analytics view.
class BloodPressureAnalyticsView extends StatelessWidget {
  const BloodPressureAnalyticsView({
    required this.period,
    required this.measurements,
    required this.previousMeasurements,
    super.key,
  });

  final DateRange period;
  final List<Measurement> measurements;
  final List<Measurement> previousMeasurements;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);

    final readings = measurements
        .where((m) => m.metricType == MetricType.bloodPressure)
        .toList();
    final summary = summariseBloodPressure(
      period: period,
      measurements: readings,
    );
    final previousSummary = summariseBloodPressure(
      period: period.previous,
      measurements: previousMeasurements,
    );
    final insights = bloodPressureInsights(
      current: summary,
      previous: previousSummary,
    );

    if (readings.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 32),
        child: EmptyState(
          icon: Icons.monitor_heart_outlined,
          title: 'No blood pressure readings',
          message:
              'Log a blood pressure reading to see trends, the guideline '
              'distribution, and diurnal comparisons.',
          actionLabel: 'Log blood pressure',
          onAction: () => context.push('/entry/blood-pressure'),
        ),
      );
    }

    final systolicChange = Change.between(
      previousSummary.systolic?.mean,
      summary.systolic?.mean,
    );
    final diastolicChange = Change.between(
      previousSummary.diastolic?.mean,
      summary.diastolic?.mean,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                label: 'Avg Systolic',
                value: summary.systolic == null
                    ? '—'
                    : formatValue(summary.systolic!.mean),
                unit: 'mmHg',
                accent: colors.metricBloodPressure,
                comparison: systolicChange == null
                    ? null
                    : '${formatSigned(systolicChange.absolute)} mmHg vs prior',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _KpiCard(
                label: 'Avg Diastolic',
                value: summary.diastolic == null
                    ? '—'
                    : formatValue(summary.diastolic!.mean),
                unit: 'mmHg',
                accent: theme.colorScheme.secondary,
                comparison: diastolicChange == null
                    ? null
                    : '${formatSigned(diastolicChange.absolute)} mmHg vs prior',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                label: 'Latest',
                value: summary.latest == null
                    ? '—'
                    : formatBloodPressure(
                        summary.latest!.value,
                        summary.latest!.secondaryValue,
                      ),
                unit: 'mmHg',
                accent: colors.metricBloodPressure,
                comparison: summary.latest?.pulse == null
                    ? null
                    : '${formatValue(summary.latest!.pulse!)} bpm resting',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _KpiCard(
                label: 'Total Volume',
                value: '${summary.readingCount}',
                unit: 'logs',
                accent: theme.colorScheme.primary,
                comparison:
                    '${(summary.completeness * 100).round()}% of days logged',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mean Daily Fluctuations',
                style: AppTypography.headlineSmall
                    .copyWith(color: theme.colorScheme.onSurface),
              ),
              Text(
                'Daily means with a ${period.dayCount}-day moving average '
                'overlay',
                style: AppTypography.bodySmall
                    .copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  _LegendDot(
                    color: colors.metricBloodPressure,
                    label: 'Systolic',
                  ),
                  _LegendDot(color: theme.colorScheme.secondary, label: 'Diastolic'),
                  _LegendDot(
                    color: theme.colorScheme.outline,
                    label: '120/80 target',
                    dashed: true,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TrendChart(
                height: 240,
                series: [
                  ChartSeries(
                    label: 'Systolic',
                    values: summary.daily.map((p) => p.systolic).toList(),
                    color: colors.metricBloodPressure,
                    fill: true,
                  ),
                  ChartSeries(
                    label: 'Diastolic',
                    values: summary.daily.map((p) => p.diastolic).toList(),
                    color: theme.colorScheme.secondary,
                  ),
                ],
                referenceLines: [
                  ReferenceLine(
                    value: 120,
                    label: '120 systolic',
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  ReferenceLine(
                    value: 80,
                    label: '80 diastolic',
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
                leftTitleBuilder: (value) => formatValue(value),
                bottomTitleBuilder: (value) {
                  final index = value.round();
                  if (index < 0 || index >= summary.daily.length) return '';
                  return shortDateLabel(summary.daily[index].day);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _GuidelineDistributionCard(summary: summary),
        const SizedBox(height: 16),
        _CircadianCard(summary: summary),
        const SizedBox(height: 16),
        _InsightsCard(insights: insights),
        const SizedBox(height: 16),
        _ExportCard(
          title: 'Doctor consultation ready',
          subtitle:
              'Includes AHA/ACC classifications, mean arterial pressure and '
              'pulse pressure.',
          onExport: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF export is planned but not implemented yet.'),
            ),
          ),
        ),
      ],
    );
  }
}

/// The weight analytics view.
class WeightAnalyticsView extends ConsumerWidget {
  const WeightAnalyticsView({
    required this.period,
    required this.measurements,
    required this.previousMeasurements,
    super.key,
  });

  final DateRange period;
  final List<Measurement> measurements;
  final List<Measurement> previousMeasurements;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);

    final readings = measurements
        .where((m) => m.metricType == MetricType.weight)
        .toList();
    final summary = summariseWeight(
      period: period,
      measurements: readings,
      previousPeriodMeasurements: previousMeasurements,
    );
    final previousSummary = summariseWeight(
      period: period.previous,
      measurements: previousMeasurements
          .where((m) => m.metricType == MetricType.weight)
          .toList(),
    );
    final insights = weightInsights(
      current: summary,
      previous: previousSummary,
    );
    final profile = ref.watch(profileProvider).value;

    if (readings.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 32),
        child: EmptyState(
          icon: Icons.monitor_weight_outlined,
          title: 'No weigh-ins yet',
          message:
              'Log your weight to see daily trends, moving averages, and '
              'period comparisons.',
          actionLabel: 'Log weight',
          onAction: () => context.push('/entry/weight'),
        ),
      );
    }

    final displayUnit = profile?.preferredMassUnit ?? Unit.kilogram;
    final baseline = summary.startingWeight ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: colors.metricWeight,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Current Weight',
                    style: AppTypography.labelMedium.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    formatValue(summary.latest!.value, precision: 1),
                    style: AppTypography.displayNumeric
                        .copyWith(color: theme.colorScheme.onSurface),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    displayUnit.symbol,
                    style: AppTypography.bodySmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (summary.changeFromPrevious != null)
                    Row(
                      children: [
                        Icon(
                          summary.changeFromPrevious!.absolute < 0
                              ? Icons.trending_down_rounded
                              : Icons.trending_up_rounded,
                          size: 16,
                          color: theme.colorScheme.secondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${formatValue(summary.changeFromPrevious!.absolute.abs(), precision: 1)}'
                          ' ${displayUnit.symbol} vs prior period',
                          style: AppTypography.labelMedium.copyWith(
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(AppRadius.control),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'STARTING BASELINE'.toUpperCase(),
                            style: AppTypography.labelMicro.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              letterSpacing: 0.8,
                            ),
                          ),
                          Text(
                            '${formatValue(baseline, precision: 1)} '
                            '${displayUnit.symbol}',
                            style: AppTypography.headlineSmall.copyWith(
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            'First reading in this period',
                            style: AppTypography.bodySmall.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Daily Weigh-ins & Trend',
                style: AppTypography.headlineSmall
                    .copyWith(color: theme.colorScheme.onSurface),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  _LegendDot(color: colors.metricWeight, label: 'Daily log'),
                  _LegendDot(
                    color: theme.colorScheme.secondary,
                    label: '7-day moving average',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TrendChart(
                height: 240,
                series: [
                  ChartSeries(
                    label: 'Daily log',
                    values: summary.daily.map((p) => p.weight).toList(),
                    color: colors.metricWeight,
                    showDots: false,
                  ),
                  ChartSeries(
                    label: '7-day moving average',
                    values: summary.daily.map((p) => p.smoothing).toList(),
                    color: theme.colorScheme.secondary,
                    showDots: false,
                  ),
                ],
                leftTitleBuilder: (value) =>
                    formatValue(value, precision: 1),
                bottomTitleBuilder: (value) {
                  final index = value.round();
                  if (index < 0 || index >= summary.daily.length) return '';
                  return shortDateLabel(summary.daily[index].day);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _PeriodPerformanceCard(summary: summary, previous: previousSummary),
        const SizedBox(height: 16),
        _InsightsCard(insights: insights),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => context.push('/entry/weight'),
          icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
          label: const Text("Log today's weight"),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.accent,
    this.comparison,
  });

  final String label;
  final String value;
  final String unit;
  final Color accent;
  final String? comparison;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelMicro.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.trending_flat_rounded, size: 14, color: accent),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: AppTypography.displayNumeric.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: AppTypography.bodySmall.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (comparison != null) ...[
            const SizedBox(height: 6),
            Text(
              comparison!,
              style: AppTypography.labelMicro.copyWith(
                color: theme.colorScheme.secondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
    this.dashed = false,
  });

  final Color color;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 3,
          decoration: BoxDecoration(
            color: dashed ? theme.colorScheme.outline : color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTypography.labelMicro.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _GuidelineDistributionCard extends StatelessWidget {
  const _GuidelineDistributionCard({required this.summary});

  final BpPeriodSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);

    final segments = <DistributionSegment>[
      DistributionSegment(
        label: 'Normal',
        count: summary.countIn(BpCategory.normal),
        color: colors.positive,
      ),
      DistributionSegment(
        label: 'Elevated',
        count: summary.countIn(BpCategory.elevated),
        color: colors.warning,
      ),
      DistributionSegment(
        label: 'Stage 1',
        count: summary.countIn(BpCategory.stage1Hypertension),
        color: colors.critical,
      ),
      DistributionSegment(
        label: 'Stage 2',
        count: summary.countIn(BpCategory.stage2Hypertension),
        color: theme.colorScheme.error,
      ),
      DistributionSegment(
        label: 'Crisis',
        count: summary.countIn(BpCategory.hypertensiveCrisis),
        color: theme.colorScheme.error.withValues(alpha: 0.7),
      ),
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Guideline Distribution',
                      style: AppTypography.headlineSmall
                          .copyWith(color: theme.colorScheme.onSurface),
                    ),
                    Text(
                      'Based on the ${summary.guideline.name} guideline',
                      style: AppTypography.bodySmall.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: '${summary.readingCount} logs',
                tone: StatusTone.neutral,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
          DistributionBar(segments: segments),
          const SizedBox(height: 12),
          Wrap(
            spacing: 20,
            runSpacing: 12,
            children: [
              for (final segment in segments)
                if (segment.count > 0)
                  DistributionLegendEntry(
                    segment: segment,
                    total: summary.readingCount,
                  ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Percentages use all ${summary.readingCount} readings in '
                    'this period as the denominator.',
                    style: AppTypography.bodySmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CircadianCard extends StatelessWidget {
  const _CircadianCard({required this.summary});

  final BpPeriodSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);

    final systolicDifference = summary.morning.systolic == null ||
            summary.evening.systolic == null
        ? null
        : summary.evening.systolic! - summary.morning.systolic!;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Circadian Rhythm & Dipping',
            style: AppTypography.headlineSmall
                .copyWith(color: theme.colorScheme.onSurface),
          ),
          Text(
            'Comparing diurnal baseline variations',
            style: AppTypography.bodySmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DiurnalTile(
                  icon: Icons.wb_sunny_rounded,
                  label: 'Morning avg',
                  value: summary.morning.systolic == null
                      ? '—'
                      : formatBloodPressure(
                          summary.morning.systolic!,
                          summary.morning.diastolic,
                        ),
                  caption: 'Between 06:00 and 11:59',
                  count: summary.morning.sampleCount,
                  accent: colors.warning,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DiurnalTile(
                  icon: Icons.nights_stay_rounded,
                  label: 'Evening avg',
                  value: summary.evening.systolic == null
                      ? '—'
                      : formatBloodPressure(
                          summary.evening.systolic!,
                          summary.evening.diastolic,
                        ),
                  caption: 'Between 18:00 and 23:59',
                  count: summary.evening.sampleCount,
                  accent: colors.metricBloodPressure,
                  footnote: systolicDifference == null
                      ? null
                      : '${formatSigned(systolicDifference)} mmHg systolic',
                ),
              ),
            ],
          ),
          if (systolicDifference != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.insights_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      systolicDifference < 0
                          ? 'Your evening readings average '
                              '${formatValue(systolicDifference.abs())} mmHg '
                              'lower systolic than your morning readings.'
                          : 'Your evening readings average '
                              '${formatValue(systolicDifference)} mmHg higher '
                              'systolic than your morning readings.',
                      style: AppTypography.bodySmall.copyWith(
                        color: theme.colorScheme.onSurface,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DiurnalTile extends StatelessWidget {
  const _DiurnalTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
    required this.count,
    required this.accent,
    this.footnote,
  });

  final IconData icon;
  final String label;
  final String value;
  final String caption;
  final int count;
  final Color accent;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: AppTypography.labelMicro.copyWith(
                    color: theme.colorScheme.onSurface,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTypography.headlineSmall
                .copyWith(color: theme.colorScheme.onSurface),
          ),
          Text(
            caption,
            style: AppTypography.bodySmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (footnote != null)
            Text(
              footnote!,
              style: AppTypography.labelMicro.copyWith(
                color: theme.colorScheme.secondary,
              ),
            ),
          Text(
            '$count reading${count == 1 ? '' : 's'}',
            style: AppTypography.labelMicro.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodPerformanceCard extends StatelessWidget {
  const _PeriodPerformanceCard({required this.summary, required this.previous});

  final WeightPeriodSummary summary;
  final WeightPeriodSummary previous;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Period Performance',
                  style: AppTypography.headlineSmall
                      .copyWith(color: theme.colorScheme.onSurface),
                ),
              ),
              StatusPill(
                label: '${summary.loggedDays} of ${summary.totalDays} days logged',
                tone: StatusTone.neutral,
                icon: Icons.check_circle_rounded,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _PerformanceRow(
            label: 'This period',
            caption: 'All weigh-ins in range',
            value: summary.stats == null
                ? '—'
                : '${formatValue(summary.stats!.mean, precision: 1)} kg avg',
            comparison: summary.changeFromPrevious == null
                ? null
                : '${formatSigned(summary.changeFromPrevious!.absolute, precision: 1)} kg',
          ),
          const SizedBox(height: 8),
          _PerformanceRow(
            label: 'Previous period',
            caption: 'Same length, immediately before',
            value: previous.stats == null
                ? '—'
                : '${formatValue(previous.stats!.mean, precision: 1)} kg avg',
          ),
          const SizedBox(height: 8),
          _PerformanceRow(
            label: 'Baseline level',
            caption: 'Mean across the selected period',
            value: summary.baseline == null
                ? '—'
                : '${formatValue(summary.baseline!, precision: 1)} kg avg',
          ),
        ],
      ),
    );
  }
}

class _PerformanceRow extends StatelessWidget {
  const _PerformanceRow({
    required this.label,
    required this.caption,
    required this.value,
    this.comparison,
  });

  final String label;
  final String caption;
  final String value;
  final String? comparison;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.labelLarge
                      .copyWith(color: theme.colorScheme.onSurface),
                ),
                Text(
                  caption,
                  style: AppTypography.labelMicro.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: AppTypography.headlineSmall
                    .copyWith(color: theme.colorScheme.onSurface),
              ),
              if (comparison != null)
                Text(
                  comparison!,
                  style: AppTypography.labelMicro.copyWith(
                    color: theme.colorScheme.secondary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.insights});

  final List<Insight> insights;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Observations',
            style: AppTypography.headlineSmall
                .copyWith(color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            'Deterministic calculations over your stored records.',
            style: AppTypography.bodySmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          for (final insight in insights) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          insight.title,
                          style: AppTypography.labelLarge
                              .copyWith(color: theme.colorScheme.onSurface),
                        ),
                      ),
                      if (insight.sampleCount != null)
                        Text(
                          'n = ${insight.sampleCount}',
                          style: AppTypography.labelMicro.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    insight.body,
                    style: AppTypography.bodySmall.copyWith(
                      color: theme.colorScheme.onSurface,
                      height: 1.5,
                    ),
                  ),
                  if (insight.limitation != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      insight.limitation!,
                      style: AppTypography.bodySmall.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _ExportCard extends StatelessWidget {
  const _ExportCard({
    required this.title,
    required this.subtitle,
    required this.onExport,
  });

  final String title;
  final String subtitle;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.medical_services_outlined,
                  size: 20,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.headlineSmall
                          .copyWith(color: theme.colorScheme.onSurface),
                    ),
                    Text(
                      subtitle,
                      style: AppTypography.bodySmall.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onExport,
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
            label: const Text('Export PDF report for doctor'),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 14,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Generated on this device — nothing is uploaded',
                style: AppTypography.labelMicro.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
