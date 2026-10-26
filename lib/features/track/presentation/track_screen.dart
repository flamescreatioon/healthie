/// The metric hub: everything the user can record, and the latest of each.
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
import '../../../shared/widgets/app_top_bar.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/selectors.dart';
import '../../../shared/widgets/states.dart';
import '../../medications/presentation/providers/medication_providers.dart';
import '../../metrics/domain/measurement.dart';
import '../../metrics/domain/metric_type.dart';
import '../../metrics/presentation/providers/measurement_providers.dart';

/// The metric hub.
class TrackScreen extends ConsumerWidget {
  const TrackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final range = DateRange.endingOn(DateTime.now(), 90);
    final measurements = ref.watch(allMeasurementsProvider(range));
    final medications = ref.watch(medicationsProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppTopBar(
              title: 'Track',
              icon: Icons.monitor_heart_rounded,
            ),
            Expanded(
              child: measurements.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: LoadingState(height: 300, lines: 4),
                ),
                error: (error, stack) => ErrorState(
                  message: "We couldn't load your measurements.",
                  onRetry: () => ref.invalidate(allMeasurementsProvider(range)),
                ),
                data: (data) => ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    Text(
                      'Record a measurement',
                      style: AppTypography.headlineLarge
                          .copyWith(color: theme.colorScheme.onSurface),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Everything here can be recorded without granting a '
                      'single health permission.',
                      style: AppTypography.bodySmall.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _MetricTile(
                      icon: Icons.monitor_heart_rounded,
                      color: colors.metricBloodPressure,
                      title: 'Blood pressure',
                      description:
                          'Systolic, diastolic, and an optional pulse, with '
                          'posture and circumstance.',
                      latest: _latestOf(data, MetricType.bloodPressure),
                      latestLabel: (m) =>
                          '${formatBloodPressure(m.value, m.secondaryValue)}'
                          ' mmHg',
                      onLog: () => context.push('/entry/blood-pressure'),
                    ),
                    const SizedBox(height: 12),
                    _MetricTile(
                      icon: Icons.monitor_weight_rounded,
                      color: colors.metricWeight,
                      title: 'Body weight',
                      description:
                          'Weight, with optional body fat and waist '
                          'circumference.',
                      latest: _latestOf(data, MetricType.weight),
                      latestLabel: (m) =>
                          '${formatValue(m.value, precision: 1)} kg',
                      onLog: () => context.push('/entry/weight'),
                    ),
                    const SizedBox(height: 12),
                    _MetricTile(
                      icon: Icons.favorite_rounded,
                      color: colors.metricHeartRate,
                      title: 'Heart rate',
                      description:
                          'Pulse in beats per minute, with context and notes.',
                      latest: _latestOf(data, MetricType.heartRate),
                      latestLabel: (m) => '${formatValue(m.value)} bpm',
                      onLog: () => context.push('/entry/heart-rate'),
                    ),
                    const SizedBox(height: 12),
                    _MetricTile(
                      icon: Icons.air_rounded,
                      color: colors.metricOxygen,
                      title: 'Blood oxygen',
                      description: 'SpO₂ saturation as a percentage.',
                      latest: _latestOf(data, MetricType.spo2),
                      latestLabel: (m) => '${formatValue(m.value)} % SpO₂',
                      isPlanned: true,
                    ),
                    const SizedBox(height: 12),
                    _MetricTile(
                      icon: Icons.thermostat_rounded,
                      color: colors.metricTemperature,
                      title: 'Body temperature',
                      description: 'Temperature in Celsius or Fahrenheit.',
                      latest: _latestOf(data, MetricType.bodyTemperature),
                      latestLabel: (m) =>
                          '${formatValue(m.value, precision: 1)} '
                          '${m.unit.symbol}',
                      isPlanned: true,
                    ),
                    const SizedBox(height: 12),
                    _MetricTile(
                      icon: Icons.water_drop_rounded,
                      color: colors.metricGlucose,
                      title: 'Blood glucose',
                      description:
                          'Concentration with fasting or post-meal context.',
                      latest: _latestOf(data, MetricType.bloodGlucose),
                      latestLabel: (m) =>
                          '${formatValue(m.value)} ${m.unit.symbol}',
                      isPlanned: true,
                    ),
                    const SizedBox(height: 24),
                    medications.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (meds) => _MedicationTile(
                        count: meds.length,
                        onManage: () => context.push('/medication'),
                        onAdd: () => context.push('/medication/entry'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SectionHeader(title: 'Latest readings'),
                    const SizedBox(height: 8),
                    if (data.isEmpty)
                      const EmptyState(
                        icon: Icons.monitor_heart_outlined,
                        title: 'Nothing recorded yet',
                        message:
                            'Your most recent readings will appear here once '
                            'you record them.',
                      )
                    else
                      for (final measurement in data.take(12))
                        _RecentRow(measurement: measurement),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Measurement? _latestOf(List<Measurement> data, MetricType type) {
    for (final measurement in data) {
      if (measurement.metricType == type) return measurement;
    }
    return null;
  }

  static void _comingSoon(BuildContext context, String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what is not implemented yet.')),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.latest,
    required this.latestLabel,
    this.onLog,
    this.isPlanned = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final Measurement? latest;
  final String Function(Measurement measurement) latestLabel;
  final VoidCallback? onLog;
  final bool isPlanned;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MetricBadge(icon: icon, color: color, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: AppTypography.headlineSmall
                            .copyWith(color: theme.colorScheme.onSurface),
                      ),
                    ),
                    if (latest != null)
                      Text(
                        latestLabel(latest!),
                        style: AppTypography.labelLarge.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: AppTypography.bodySmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: Row(
                    children: [
                      if (isPlanned)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            'Planned metric',
                            style: AppTypography.labelMicro.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      else
                        FilledButton.icon(
                          onPressed: onLog,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 40),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Log'),
                        ),
                    ],
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

/// Entry point to medication tracking: shows the active count and routes to
/// the medication hub (`/medication`) or straight to the add screen.
class _MedicationTile extends ConsumerWidget {
  const _MedicationTile({
    required this.count,
    required this.onManage,
    required this.onAdd,
  });

  final int count;
  final VoidCallback onManage;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MetricBadge(
            icon: Icons.medication_rounded,
            color: theme.colorScheme.primary,
            size: 44,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Medications',
                        style: AppTypography.headlineSmall
                            .copyWith(color: theme.colorScheme.onSurface),
                      ),
                    ),
                    Text(
                      count == 0
                          ? 'None yet'
                          : '$count active',
                      style: AppTypography.labelLarge.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Doses, schedules, and adherence — with optional reminders.',
                  style: AppTypography.bodySmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: Row(
                    children: [
                      FilledButton.icon(
                        onPressed: onAdd,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: onManage,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: const Text('Manage'),
                      ),
                    ],
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

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.measurement});

  final Measurement measurement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              measurement.metricType == MetricType.bloodPressure
                  ? 'Blood pressure'
                  : measurement.metricType == MetricType.weight
                      ? 'Body weight'
                      : measurement.spec.displayName,
              style: AppTypography.bodyMedium
                  .copyWith(color: theme.colorScheme.onSurface),
            ),
          ),
          Text(
            timestampLabel(measurement.recordedAt, now: DateTime.now()),
            style: AppTypography.bodySmall
                .copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
