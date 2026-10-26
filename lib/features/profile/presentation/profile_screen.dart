/// The profile screen: identity, units, targets, reminders, and privacy.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_typography.dart';
import '../../../core/units/unit.dart';
import '../../../core/utils/id_generator.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_top_bar.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/selectors.dart';
import '../../metrics/domain/metric_type.dart';
import '../../profile/domain/health_profile.dart';
import '../../profile/presentation/providers/profile_providers.dart';
import '../../reminders/domain/reminder.dart';
import '../../reminders/presentation/providers/reminder_providers.dart';

/// The profile and settings screen.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(profileProvider).value;
    final reminders = ref.watch(remindersProvider).value ?? const <Reminder>[];
    final notificationsAllowedAsync =
        ref.watch(notificationPermissionProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppTopBar(
              title: 'Profile & Settings',
              icon: Icons.person_rounded,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Profile',
                          style: AppTypography.headlineSmall
                              .copyWith(color: theme.colorScheme.onSurface),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Only fill in what you want to use. Everything stays '
                          'on this device.',
                          style: AppTypography.bodySmall.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          key: const ValueKey('profile-name-field'),
                          controller: TextEditingController(
                            text: profile?.displayName ?? '',
                          ),
                          onSubmitted: (value) => _saveProfile(
                            ref,
                            profile,
                            value.trim(),
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Preferred name',
                            hintText: 'What should we call you?',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SectionHeader(
                    title: 'Units',
                    subtitle: 'Values are stored in metric units and converted '
                        'for display.',
                  ),
                  const SizedBox(height: 8),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mass',
                          style: AppTypography.labelMedium.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SegmentedControl<Unit>(
                          options: const [Unit.kilogram, Unit.pound],
                          selected:
                              profile?.preferredMassUnit ?? Unit.kilogram,
                          onChanged: (unit) => _saveProfile(
                            ref,
                            profile,
                            null,
                            preferredMassUnit: unit,
                          ),
                          labelBuilder: (unit) => unit.symbol,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Blood pressure targets',
                          style: AppTypography.labelMedium.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Optional. Set a target only if a clinician gave you '
                          'one.',
                          style: AppTypography.bodySmall.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                key: const ValueKey('target-systolic-field'),
                                controller: TextEditingController(
                                  text: profile?.targetSystolic?.toString() ??
                                      '',
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'Systolic',
                                  suffixText: 'mmHg',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                key: const ValueKey('target-diastolic-field'),
                                controller: TextEditingController(
                                  text:
                                      profile?.targetDiastolic?.toString() ??
                                          '',
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'Diastolic',
                                  suffixText: 'mmHg',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SectionHeader(
                    title: 'Reminders',
                    subtitle:
                        'Reminders are local notifications and depend on your '
                        'device settings.',
                  ),
                  const SizedBox(height: 8),
                  AppCard(
                    child: Column(
                      children: [
                        notificationsAllowedAsync.when(
                          data: (allowed) => SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'Notifications',
                              style: AppTypography.labelLarge.copyWith(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            subtitle: Text(
                              allowed
                                  ? 'Enabled'
                                  : 'Tap to enable reminders',
                              style: AppTypography.bodySmall.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            value: allowed,
                            onChanged: (value) {
                              if (value) {
                                ref
                                    .read(notificationPermissionProvider.notifier)
                                    .request();
                              }
                            },
                          ),
                          loading: () => const SizedBox.shrink(),
                          error: (_, _) => const SizedBox.shrink(),
                        ),
                        notificationsAllowedAsync.when(
                          data: (allowed) => allowed
                              ? const SizedBox.shrink()
                              : _NotificationPermissionBanner(
                                  onEnable: () => ref
                                      .read(notificationPermissionProvider
                                          .notifier)
                                      .request(),
                                ),
                          loading: () => const SizedBox.shrink(),
                          error: (_, _) => const SizedBox.shrink(),
                        ),
                        if (reminders.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'No reminders set up yet.',
                              style: AppTypography.bodySmall.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        else
                          for (final reminder in reminders)
                            Material(
                              color: Colors.transparent,
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Switch(
                                  value: reminder.enabled,
                                  onChanged: (value) => ref
                                      .read(reminderControllerProvider)
                                      .setEnabled(reminder, enabled: value),
                                ),
                                title: Text(
                                  reminder.title,
                                  style: AppTypography.labelLarge.copyWith(
                                    color: reminder.enabled
                                        ? theme.colorScheme.onSurface
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                subtitle: Text(
                                  '${reminder.hour.toString().padLeft(2, '0')}:'
                                  '${reminder.minute.toString().padLeft(2, '0')}',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: reminder.enabled
                                        ? theme.colorScheme.onSurfaceVariant
                                        : theme.colorScheme.onSurfaceVariant
                                            .withValues(alpha: 0.6),
                                  ),
                                ),
                                trailing: IconButton(
                                  icon:
                                      const Icon(Icons.delete_outline, size: 20),
                                  color: theme.colorScheme.error,
                                  onPressed: () => _confirmDeleteReminder(
                                    context, ref, reminder,
                                  ),
                                ),
                              ),
                            ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => ref
                              .read(reminderControllerProvider)
                              .seedDefaults(),
                          icon: const Icon(Icons.alarm_add_rounded, size: 18),
                          label: const Text('Add default BP reminders'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => _showAddReminderDialog(context, ref),
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          label: const Text('Add custom reminder'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SectionHeader(title: 'Data & privacy'),
                  const SizedBox(height: 8),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your health data never leaves this device unless you '
                          'explicitly export it. There is no analytics SDK and '
                          'no advertising SDK in this app.',
                          style: AppTypography.bodySmall.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Healthie is a personal tracker, not a medical '
                          'device. It does not diagnose, and it does not '
                          'replace professional medical advice.',
                          style: AppTypography.bodySmall.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Confirm deletion of a reminder.
  static Future<void> _confirmDeleteReminder(
    BuildContext context,
    WidgetRef ref,
    Reminder reminder,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete reminder?'),
        content: Text('Remove "${reminder.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(reminderControllerProvider).delete(reminder.id);
    }
  }

  /// Show a dialog to create a custom reminder.
  static Future<void> _showAddReminderDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final titleController = TextEditingController();
    var hour = 8;
    var minute = 0;
    MetricType? selectedType;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add custom reminder'),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Reminder title',
                    hintText: 'e.g. Morning pills',
                  ),
                ),
                const SizedBox(height: 12),
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    title: const Text('Time'),
                    subtitle: Text(
                      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
                    ),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      Navigator.of(dialogContext).pop();
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(hour: hour, minute: minute),
                      );
                      if (picked != null && context.mounted) {
                        hour = picked.hour;
                        minute = picked.minute;
                        // Re-open dialog to reflect new time
                        await _showAddReminderDialog(context, ref);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButton<MetricType>(
                  isExpanded: true,
                  hint: const Text('Metric type'),
                  value: selectedType,
                  items: MetricCatalog.all.map((spec) {
                    return DropdownMenuItem<MetricType>(
                      value: spec.type,
                      child: Text(spec.displayName),
                    );
                  }).toList(),
                  onChanged: (value) => selectedType = value,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: titleController.text.isEmpty || selectedType == null
                  ? null
                  : () async {
                      final id = newId();
                      await ref.read(reminderControllerProvider).save(
                        Reminder(
                          id: id,
                          kind: ReminderKind.custom,
                          metricType: selectedType!.wireName,
                          title: titleController.text.trim(),
                          hour: hour,
                          minute: minute,
                        ),
                      );
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  static void _saveProfile(
    WidgetRef ref,
    HealthProfile? profile,
    String? displayName, {
    Unit? preferredMassUnit,
  }) {
    final current = profile ?? const HealthProfile(id: 'me');
    ref.read(profileControllerProvider).save(
          current.copyWith(
            displayName: displayName ?? current.displayName,
            preferredMassUnit: preferredMassUnit ?? current.preferredMassUnit,
          ),
        );
  }
}

/// Explains why reminders need the OS notification permission and asks for
/// it. Rendered at the top of the reminders card when the permission is
/// missing — the prompt needs the user's attention, so it lives at the
/// moment the user wants the feature, not at app startup.
class _NotificationPermissionBanner extends ConsumerWidget {
  const _NotificationPermissionBanner({required this.onEnable});

  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.notifications_off_outlined,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Allow notifications so your reminders can fire. Nothing '
              'leaves this device.',
              style: AppTypography.bodySmall.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.tonal(
            onPressed: onEnable,
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }
}
