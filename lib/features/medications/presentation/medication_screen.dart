/// Medication list screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../features/medications/domain/medication.dart';
import '../../../features/medications/presentation/providers/medication_providers.dart';
import '../../../features/reminders/domain/reminder.dart';
import '../../../features/reminders/presentation/providers/reminder_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_top_bar.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/states.dart';

/// The medication hub: list medications, log doses, view adherence.
class MedicationScreen extends ConsumerWidget {
  const MedicationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final medsAsync = ref.watch(medicationsProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppTopBar(
        title: 'Medications',
        icon: Icons.medication_rounded,
        actions: [
          IconButton(
            tooltip: 'Add medication',
            icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
            onPressed: () => context.push('/medication/entry'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: medsAsync.when(
          data: (meds) {
            if (meds.isEmpty) {
              return EmptyState(
                icon: Icons.medication_outlined,
                title: 'No medications yet',
                message: 'Add your first medication to start tracking '
                    'doses and adherence.',
                actionLabel: 'Add Medication',
                onAction: () => context.push('/medication/entry'),
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                SectionHeader(
                  title: 'Your Medications',
                  subtitle: '${meds.length} active',
                ),
                const SizedBox(height: 12),
                for (final medication in meds) ...[
                  _MedicationTile(medication: medication),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: LoadingState(height: 300, lines: 4),
          ),
          error: (_, _) => ErrorState(
            message: 'Could not load medications.',
            onRetry: () => ref.invalidate(medicationsProvider),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add medication',
        onPressed: () => context.push('/medication/entry'),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

/// A single medication row with next dose and log button.
class _MedicationTile extends ConsumerWidget {
  const _MedicationTile({required this.medication});

  final Medication medication;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final times = medication.schedule.split(',').map((t) => t.trim()).toList();

    final logsAsync = ref.watch(medicationLogsProvider);
    final medLogs = logsAsync.when(
          data: (logs) => logs
              .where((log) => log.medicationId == medication.id)
              .toList(),
          loading: () => const <MedicationLog>[],
          error: (_, _) => const <MedicationLog>[],
        );
    final nextDoseDisplay =
        _nextDoseDisplay(_nextDoseTime(times), logsAsync);
    final takenCount =
        medLogs.where((log) => log.status == MedicationLogStatus.taken).length;
    final adherence = medLogs.isEmpty ? null : takenCount / medLogs.length;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.medication_rounded,
                  size: 24,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medication.name,
                      style: AppTypography.headlineSmall.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      medication.dosageInstructions,
                      style: AppTypography.bodySmall.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Next: $nextDoseDisplay',
                      style: AppTypography.labelMicro.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (adherence != null) ...[
                const SizedBox(width: 12),
                _AdherenceChip(adherence: adherence),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () =>
                      context.push('/medication/log/${medication.id}'),
                  icon:
                      const Icon(Icons.add_circle_outline_rounded, size: 18),
                  label: const Text('Log dose'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _ReminderToggle(medication: medication),
            ],
          ),
        ],
      ),
    );
  }

  /// The next scheduled dose as `HH:MM`, or a fallback label when the
  /// schedule is empty or the log state cannot be read.
  String _nextDoseDisplay(
    String? nextDose,
    AsyncValue<List<MedicationLog>> logsAsync,
  ) {
    return logsAsync.when(
      data: (_) => nextDose ?? 'no schedule',
      loading: () => '…',
      error: (_, __) => nextDose ?? 'no schedule',
    );
  }

  String? _nextDoseTime(List<String> times) {
    final now = DateTime.now();
    final currentTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    for (final t in times) {
      if (t.compareTo(currentTime) > 0) {
        return t;
      }
    }
    return times.isEmpty ? null : times.first;
  }
}

/// Toggles dose reminders for one medication, creating or removing the
/// linked `medication`-kind reminders to match its schedule.
class _ReminderToggle extends ConsumerWidget {
  const _ReminderToggle({required this.medication});

  final Medication medication;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final reminders = ref.watch(remindersProvider).value ?? const <Reminder>[];
    final linked = reminders.where(
      (reminder) =>
          reminder.kind == ReminderKind.medication &&
          reminder.metricType == 'medication:${medication.id}',
    );
    final enabled = linked.any((reminder) => reminder.enabled);

    return TextButton.icon(
      onPressed: () async {
        final controller = ref.read(medicationControllerProvider);
        if (enabled) {
          await controller.removeDoseReminders(medication.id);
        } else {
          await controller.syncDoseReminders(medication);
        }
      },
      icon: Icon(
        enabled ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
        size: 16,
      ),
      label: Text(enabled ? 'Reminders on' : 'Remind me'),
      style: TextButton.styleFrom(
        foregroundColor: enabled
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        minimumSize: const Size(0, 36),
      ),
    );
  }
}

/// Adherence percentage chip.
class _AdherenceChip extends StatelessWidget {
  const _AdherenceChip({required this.adherence});

  final double adherence;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final color = adherence >= 0.8
        ? colors.positive
        : adherence >= 0.5
            ? colors.warning
            : colors.critical;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${(adherence * 100).round()}%',
            style: AppTypography.labelMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'adherent',
            style: AppTypography.labelMicro.copyWith(
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
