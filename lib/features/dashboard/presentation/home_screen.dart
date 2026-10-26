/// The home dashboard.
///
/// One screen that answers "how am I doing?" — the latest readings, the
/// trends behind them, and one observation drawn from the data. Everything
/// shown here comes from stored measurements; nothing is invented to fill
/// the layout.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/utils/date_range.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/formatters/value_formatter.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/charts/mini_charts.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/states.dart';
import '../../analytics/domain/blood_pressure_analytics.dart';
import '../../analytics/domain/insight.dart';
import '../../analytics/domain/statistics.dart';
import '../../metrics/domain/blood_pressure_guideline.dart';
import '../../metrics/domain/measurement.dart';
import '../../metrics/domain/metric_type.dart';
import '../../profile/presentation/providers/profile_providers.dart';
import '../../reminders/domain/reminder.dart';
import '../../reminders/presentation/providers/reminder_providers.dart';
import 'providers/dashboard_providers.dart';

/// The dashboard.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final measurements = ref.watch(dashboardMeasurementsProvider);
    final profile = ref.watch(profileProvider).value;
    final reminders = ref.watch(remindersProvider).value ?? const <Reminder>[];

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        bottom: false,
        child: measurements.when(
          loading: () => const _HomeSkeleton(),
          error: (error, stack) => ErrorState(
            message: "We couldn't load your readings.",
            onRetry: () => ref.invalidate(dashboardMeasurementsProvider),
          ),
          data: (data) => _HomeBody(
            measurements: data,
            displayName: profile?.displayName,
            reminders: reminders,
          ),
        ),
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({
    required this.measurements,
    required this.displayName,
    required this.reminders,
  });

  final List<Measurement> measurements;
  final String? displayName;
  final List<Reminder> reminders;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final theme = Theme.of(context);

    final bloodPressure = _ofType(measurements, MetricType.bloodPressure);
    final weight = _ofType(measurements, MetricType.weight);
    final heartRate = _ofType(measurements, MetricType.heartRate);
    final spo2 = _ofType(measurements, MetricType.spo2);

    final latestBp = bloodPressure.isEmpty ? null : bloodPressure.first;
    final latestWeight = weight.isEmpty ? null : weight.first;
    final latestHr = heartRate.isEmpty ? null : heartRate.first;
    final latestSpo2 = spo2.isEmpty ? null : spo2.first;

    final period = DateRange(
      start: startOfLocalDay(now).subtract(const Duration(days: 29)),
      end: startOfLocalDay(now).add(const Duration(days: 1)),
    );
    final previousPeriod = DateRange(
      start: period.start.subtract(const Duration(days: 30)),
      end: period.start,
    );

    final summary = summariseBloodPressure(
      period: period,
      measurements: bloodPressure,
    );
    final previousSummary = summariseBloodPressure(
      period: previousPeriod,
      measurements: bloodPressure,
    );
    final insight = dashboardInsight(
      current: summary,
      previous: previousSummary,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 14,
                        color: theme.colorScheme.tertiary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _dateLabel(now),
                        style: AppTypography.labelMedium.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _greeting(now, displayName),
                    style: AppTypography.headlineLarge.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Reminders',
              icon: const Icon(Icons.notifications_active_outlined),
              onPressed: () => context.go('/profile'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _StreakBanner(measurements: measurements, now: now),
        const SizedBox(height: 16),
        _QuickActions(),
        const SizedBox(height: 16),
        if (reminders.isNotEmpty) ...[
          _ProtocolChecklist(reminders: reminders, measurements: measurements),
          const SizedBox(height: 16),
        ],
        _BloodPressureCard(
          latest: latestBp,
          measurements: bloodPressure,
          now: now,
        ),
        const SizedBox(height: 16),
        _WeightCard(
          latest: latestWeight,
          measurements: weight,
          now: now,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _CompactMetricCard(
                icon: Icons.favorite_rounded,
                color: AppColors.of(context).metricHeartRate,
                label: 'Resting HR',
                value: latestHr == null ? null : formatValue(latestHr.value),
                unit: 'bpm',
                footnote: _sevenDayAverageLabel(heartRate),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CompactMetricCard(
                icon: Icons.air_rounded,
                color: AppColors.of(context).metricOxygen,
                label: 'Blood Oxygen',
                value: latestSpo2 == null ? null : formatValue(latestSpo2.value),
                unit: '% SpO2',
                footnote: latestSpo2 == null
                    ? null
                    : 'Measured ${timestampLabel(latestSpo2.recordedAt, now: now)}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _InsightCard(insight: insight),
        const SizedBox(height: 16),
        if (reminders.isNotEmpty) ...[
          _UpcomingCheckCard(reminders: reminders, now: now),
          const SizedBox(height: 16),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Healthie is for personal health tracking and informational purposes only, '
            'not a substitute for professional medical diagnosis or clinical care.',
            textAlign: TextAlign.center,
            style: AppTypography.labelMicro.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ),
      ],
    );
  }

  static List<Measurement> _ofType(
    List<Measurement> measurements,
    MetricType type,
  ) =>
      measurements.where((m) => m.metricType == type).toList();

  static String _dateLabel(DateTime now) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

  static String _greeting(DateTime now, String? displayName) {
    final hour = now.hour;
    final part = hour < 12
        ? 'Good morning'
        : hour < 18
            ? 'Good afternoon'
            : 'Good evening';
    final name = (displayName == null || displayName.trim().isEmpty)
        ? null
        : displayName.trim();
    return name == null ? part : '$part, $name';
  }

  static String? _sevenDayAverageLabel(List<Measurement> measurements) {
    if (measurements.isEmpty) return null;
    final cutoff = startOfLocalDay(DateTime.now()).subtract(const Duration(days: 6));
    final recent = measurements
        .where((m) => m.recordedAt.toLocal().isAfter(cutoff))
        .toList();
    if (recent.isEmpty) return null;
    final stats = DescriptiveStats.from(recent.map((m) => m.value).toList());
    return '7d avg: ${formatValue(stats!.mean)} bpm';
  }
}

class _StreakBanner extends StatelessWidget {
  const _StreakBanner({required this.measurements, required this.now});

  final List<Measurement> measurements;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = _loggedDays(measurements);
    final streak = _streak(days, now);
    if (streak < 2) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: theme.colorScheme.tertiary.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiary.withValues(alpha: 0.20),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.event_available_rounded,
              size: 20,
              color: theme.colorScheme.tertiary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Consistent tracking: $streak days logged. Keep up your routine!',
              style: AppTypography.bodySmall
                  .copyWith(color: theme.colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  static Set<DateTime> _loggedDays(List<Measurement> measurements) =>
      measurements.map((m) => startOfLocalDay(m.recordedAt)).toSet();

  static int _streak(Set<DateTime> days, DateTime now) {
    var streak = 0;
    var cursor = startOfLocalDay(now);
    // Today not being logged yet should not break yesterday's streak.
    if (!days.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    while (days.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          _QuickAction(
            label: 'Log BP',
            icon: Icons.add_rounded,
            filled: true,
            onTap: () => context.push('/entry/blood-pressure'),
          ),
          const SizedBox(width: 8),
          _QuickAction(
            label: 'Log Weight',
            icon: Icons.add_rounded,
            onTap: () => context.push('/entry/weight'),
          ),
          const SizedBox(width: 8),
          _QuickAction(
            label: 'Log Glucose',
            icon: Icons.add_rounded,
            onTap: () => context.go('/track'),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: filled
          ? theme.colorScheme.primary
          : theme.colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: filled
                ? null
                : Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: filled
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.labelMedium.copyWith(
                  color: filled
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProtocolChecklist extends StatelessWidget {
  const _ProtocolChecklist({required this.reminders, required this.measurements});

  final List<Reminder> reminders;
  final List<Measurement> measurements;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final loggedTypes = measurements
        .where((m) => isSameLocalDay(m.recordedAt, now))
        .map((m) => m.metricType.wireName)
        .toSet();

    final entries = reminders.take(4).toList();
    final complete = entries
        .where((r) => loggedTypes.contains(r.metricType))
        .length;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "TODAY'S PROTOCOL".toUpperCase(),
                  style: AppTypography.labelMicro.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Text(
                '$complete of ${entries.length} complete',
                style: AppTypography.labelMedium.copyWith(
                  color: theme.colorScheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final reminder in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    loggedTypes.contains(reminder.metricType)
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 20,
                    color: loggedTypes.contains(reminder.metricType)
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reminder.title,
                      style: AppTypography.labelMedium
                          .copyWith(color: theme.colorScheme.onSurface),
                    ),
                  ),
                  Text(
                    '${reminder.hour.toString().padLeft(2, '0')}:'
                    '${reminder.minute.toString().padLeft(2, '0')}',
                    style: AppTypography.bodySmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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

class _BloodPressureCard extends StatelessWidget {
  const _BloodPressureCard({
    required this.latest,
    required this.measurements,
    required this.now,
  });

  final Measurement? latest;
  final List<Measurement> measurements;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);

    if (latest == null) {
      return AppCard(
        elevated: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Blood Pressure',
              style: AppTypography.headlineSmall
                  .copyWith(color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              'No blood pressure readings yet. Log your first reading to start '
              'building a trend.',
              style: AppTypography.bodySmall
                  .copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.push('/entry/blood-pressure'),
              icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
              label: const Text('Log blood pressure'),
            ),
          ],
        ),
      );
    }

    final category = latest!.secondaryValue == null
        ? null
        : classifyBloodPressure(
            systolic: latest!.value.round(),
            diastolic: latest!.secondaryValue!.round(),
          );

    final cutoff = startOfLocalDay(now).subtract(const Duration(days: 6));
    final recent = measurements
        .where((m) => m.recordedAt.toLocal().isAfter(cutoff))
        .toList();
    final systolicSeries = _dailySeries(recent.map((m) => m.value).toList());
    final diastolicSeries =
        _dailySeries(recent.map((m) => m.secondaryValue).toList());

    return AppCard(
      elevated: true,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.metricBloodPressure.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.monitor_heart_rounded,
                  size: 22,
                  color: colors.metricBloodPressure,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Blood Pressure',
                      style: AppTypography.headlineSmall
                          .copyWith(color: theme.colorScheme.onSurface),
                    ),
                    Text(
                      '${relativeDayLabel(latest!.recordedAt, now: now)}, ${timeOfDayLabel(latest!.recordedAt)}',
                      style: AppTypography.bodySmall.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (category != null)
                StatusPill(
                  label: _categoryLabel(category),
                  tone: _categoryTone(category),
                  icon: Icons.check_circle_rounded,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: formatValue(latest!.value),
                        style: AppTypography.displayNumeric
                            .copyWith(color: theme.colorScheme.onSurface),
                      ),
                      TextSpan(
                        text: ' / '
                            '${latest!.secondaryValue == null ? '—' : formatValue(latest!.secondaryValue!)}',
                        style: AppTypography.displayNumeric.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                'mmHg',
                style: AppTypography.bodySmall.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (latest!.pulse != null) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.favorite_rounded,
                        size: 14,
                        color: theme.colorScheme.secondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${formatValue(latest!.pulse!)} bpm',
                        style: AppTypography.labelMedium
                            .copyWith(color: theme.colorScheme.onSurface),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '7-DAY DUAL TREND (SYS / DIA)',
                        style: AppTypography.labelMicro.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    Text(
                      'Stable band',
                      style: AppTypography.labelMicro.copyWith(
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      Expanded(
                        child: Sparkline(
                          values: systolicSeries,
                          color: colors.metricBloodPressure,
                          fill: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Sparkline(
                          values: diastolicSeries,
                          color: theme.colorScheme.secondary,
                          showEndDot: false,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () => context.push('/entry/blood-pressure'),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                  label: const Text('Log blood pressure'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.go('/analytics'),
                  child: const Text('Analytics'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static List<double?> _dailySeries(List<double?> values) {
    final present = values.whereType<double>().toList();
    if (present.isEmpty) return const [];
    return present.reversed.toList();
  }

  static String _categoryLabel(BpCategory category) => switch (category) {
        BpCategory.normal => 'Optimal',
        BpCategory.elevated => 'Elevated',
        BpCategory.stage1Hypertension => 'Stage 1',
        BpCategory.stage2Hypertension => 'Stage 2',
        BpCategory.hypertensiveCrisis => 'Seek care',
      };

  static StatusTone _categoryTone(BpCategory category) => switch (category) {
        BpCategory.normal => StatusTone.positive,
        BpCategory.elevated => StatusTone.warning,
        BpCategory.stage1Hypertension => StatusTone.warning,
        BpCategory.stage2Hypertension => StatusTone.critical,
        BpCategory.hypertensiveCrisis => StatusTone.critical,
      };
}

class _WeightCard extends StatelessWidget {
  const _WeightCard({
    required this.latest,
    required this.measurements,
    required this.now,
  });

  final Measurement? latest;
  final List<Measurement> measurements;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);

    if (latest == null) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weight',
              style: AppTypography.headlineSmall
                  .copyWith(color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              'No weigh-ins yet. Log your first weight to start building a '
              'trend.',
              style: AppTypography.bodySmall
                  .copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => context.push('/entry/weight'),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Log weight'),
            ),
          ],
        ),
      );
    }

    final cutoff = startOfLocalDay(now).subtract(const Duration(days: 29));
    final month = measurements
        .where((m) => m.recordedAt.toLocal().isAfter(cutoff))
        .toList();
    final baseline = DescriptiveStats.from(month.map((m) => m.value).toList());
    final delta = baseline == null ? null : latest!.value - baseline.mean;

    final series = measurements
        .take(30)
        .map((m) => m.value)
        .toList()
        .reversed
        .toList();

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.metricWeight.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.monitor_weight_rounded,
                  size: 20,
                  color: colors.metricWeight,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weight',
                      style: AppTypography.headlineSmall
                          .copyWith(color: theme.colorScheme.onSurface),
                    ),
                    Text(
                      'Last weighed ${relativeDayLabel(latest!.recordedAt, now: now).toLowerCase()}',
                      style: AppTypography.bodySmall.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: 'Metric (kg)',
                tone: StatusTone.neutral,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatValue(latest!.value, precision: 1),
                style: AppTypography.displayNumeric
                    .copyWith(color: theme.colorScheme.onSurface),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'kg',
                  style: AppTypography.bodySmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const Spacer(),
              if (delta != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        delta < 0
                            ? Icons.trending_down_rounded
                            : Icons.trending_up_rounded,
                        size: 14,
                        color: theme.colorScheme.secondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${formatValue(delta.abs(), precision: 1)} kg vs 30d',
                        style: AppTypography.labelMicro.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: Sparkline(
              values: series,
              color: colors.metricWeight,
              fill: true,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: FilledButton.icon(
              onPressed: () => context.push('/entry/weight'),
              style: FilledButton.styleFrom(
                backgroundColor: colors.metricWeight,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Log weight'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactMetricCard extends StatelessWidget {
  const _CompactMetricCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.unit,
    this.footnote,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String? value;
  final String unit;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value ?? '—',
                style: AppTypography.headlineLarge
                    .copyWith(color: theme.colorScheme.onSurface),
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
          if (footnote != null) ...[
            const SizedBox(height: 8),
            Text(
              footnote!,
              style: AppTypography.labelMicro.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});

  final Insight insight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: theme.colorScheme.tertiary.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lightbulb_rounded,
                  size: 20,
                  color: theme.colorScheme.onTertiary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      insight.title,
                      style: AppTypography.labelMedium.copyWith(
                        color: theme.colorScheme.tertiary,
                      ),
                    ),
                    Text(
                      insight.kind == InsightKind.sparsity
                          ? 'Data completeness'
                          : 'Clinical observation',
                      style: AppTypography.labelMicro.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            insight.body,
            style: AppTypography.bodySmall.copyWith(
              color: theme.colorScheme.onSurface,
              height: 1.5,
            ),
          ),
          if (insight.limitation != null) ...[
            const SizedBox(height: 8),
            Text(
              insight.limitation!,
              style: AppTypography.bodySmall.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.go('/analytics'),
              child: const Text('Inspect 30-day trend'),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingCheckCard extends ConsumerWidget {
  const _UpcomingCheckCard({required this.reminders, required this.now});

  final List<Reminder> reminders;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final enabled = reminders.where((r) => r.enabled).toList()
      ..sort((a, b) => a.nextOccurrence(now).compareTo(b.nextOccurrence(now)));
    if (enabled.isEmpty) return const SizedBox.shrink();
    final next = enabled.first;
    final occurrence = next.nextOccurrence(now);

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.alarm_rounded,
              size: 22,
              color: theme.colorScheme.tertiary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'UPCOMING CHECK',
                  style: AppTypography.labelMicro.copyWith(
                    color: theme.colorScheme.tertiary,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  next.title,
                  style: AppTypography.labelLarge
                      .copyWith(color: theme.colorScheme.onSurface),
                ),
                Text(
                  '${relativeDayLabel(occurrence, now: now)} at '
                  '${timeOfDayLabel(occurrence)}',
                  style: AppTypography.bodySmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: next.enabled,
            onChanged: (value) => ref
                .read(reminderControllerProvider)
                .setEnabled(next, enabled: value),
          ),
        ],
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LoadingState(height: 200, lines: 2),
          SizedBox(height: 16),
          LoadingState(height: 120, lines: 2),
          SizedBox(height: 16),
          LoadingState(height: 120, lines: 2),
        ],
      ),
    );
  }
}
