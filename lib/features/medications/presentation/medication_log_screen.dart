/// Log a medication dose (taken / skipped / missed).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../features/medications/domain/medication.dart';
import '../../../features/medications/presentation/providers/medication_providers.dart';
import '../../../shared/form/entry_widgets.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_top_bar.dart';

/// Logs a dose for [medicationId].
class MedicationLogScreen extends ConsumerStatefulWidget {
  const MedicationLogScreen({super.key, required this.medicationId});

  final String medicationId;

  @override
  ConsumerState<MedicationLogScreen> createState() =>
      _MedicationLogScreenState();
}

class _MedicationLogScreenState extends ConsumerState<MedicationLogScreen> {
  final _notesController = TextEditingController();
  MedicationLogStatus _status = MedicationLogStatus.taken;
  DateTime _loggedAt = DateTime.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    final log = MedicationLog(
      id: _newId(),
      medicationId: widget.medicationId,
      scheduledAt: _loggedAt,
      status: _status,
      recordedAt: DateTime.now(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    await ref.read(medicationControllerProvider).logMedication(log);

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.of(context).maybePop();
    }
  }

  String _newId() {
    return '${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppTopBar(
        title: 'Log Dose',
        icon: Icons.medication_rounded,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            AppCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status',
                    style: AppTypography.labelMedium.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _StatusChip(
                        status: MedicationLogStatus.taken,
                        selected: _status == MedicationLogStatus.taken,
                        onChanged: (v) => setState(() => _status = v),
                        label: 'Taken',
                        icon: Icons.check_circle_rounded,
                        color: colors.positive,
                      ),
                      _StatusChip(
                        status: MedicationLogStatus.skipped,
                        selected: _status == MedicationLogStatus.skipped,
                        onChanged: (v) => setState(() => _status = v),
                        label: 'Skipped',
                        icon: Icons.skip_next_rounded,
                        color: colors.warning,
                      ),
                      _StatusChip(
                        status: MedicationLogStatus.missed,
                        selected: _status == MedicationLogStatus.missed,
                        onChanged: (v) => setState(() => _status = v),
                        label: 'Missed',
                        icon: Icons.cancel_rounded,
                        color: colors.critical,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Logged At',
                    style: AppTypography.labelMedium.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const ValueKey('medication-log-time-field'),
                    controller: TextEditingController(
                      text: DateFormat('MMM d, yyyy, h:mm a')
                          .format(_loggedAt.toLocal()),
                    ),
                    style: AppTypography.bodyMedium,
                    decoration: const InputDecoration(
                      hintText: 'Select date and time',
                    ),
                    readOnly: true,
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: _loggedAt,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (!context.mounted) return;
                      if (pickedDate == null) return;
                      final pickedTime = await showTimePicker(
                        // ignore: use_build_context_synchronously
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(_loggedAt),
                      );
                      if (!mounted) return;
                      if (pickedTime == null) return;
                      setState(() {
                        _loggedAt = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Notes (Optional)',
                    style: AppTypography.labelMedium.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const ValueKey('medication-log-notes-field'),
                    controller: _notesController,
                    maxLines: 3,
                    style: AppTypography.bodyMedium,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Took with food',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.94),
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outlineVariant
                        .withValues(alpha: 0.7),
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: SaveButton(
                  label: 'Log Dose',
                  isSaving: _isSaving,
                  onPressed: _save,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A selectable status chip for dose logging.
class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.status,
    required this.selected,
    required this.onChanged,
    required this.label,
    required this.icon,
    required this.color,
  });

  final MedicationLogStatus status;
  final bool selected;
  final ValueChanged<MedicationLogStatus> onChanged;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilterChip(
      selected: selected,
      onSelected: (_) => onChanged(status),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: selected ? color : theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.labelMedium.copyWith(
              color: selected ? color : theme.colorScheme.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
      selectedColor: color.withValues(alpha: 0.15),
      checkmarkColor: color,
      backgroundColor: theme.colorScheme.surfaceContainerLow,
    );
  }
}
