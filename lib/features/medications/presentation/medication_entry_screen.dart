/// Add/edit a medication.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_typography.dart';
import '../../../features/medications/domain/medication.dart';
import '../../../features/medications/presentation/providers/medication_providers.dart';
import '../../../shared/form/entry_widgets.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_top_bar.dart';

/// Records a new medication or edits an existing one.
class MedicationEntryScreen extends ConsumerStatefulWidget {
  const MedicationEntryScreen({super.key, this.medication});

  final Medication? medication;

  @override
  ConsumerState<MedicationEntryScreen> createState() =>
      _MedicationEntryScreenState();
}

class _MedicationEntryScreenState
    extends ConsumerState<MedicationEntryScreen> {
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _scheduleController = TextEditingController();

  bool _isSaving = false;
  bool _remindMe = false;

  @override
  void initState() {
    super.initState();
    final medication = widget.medication;
    if (medication != null) {
      _nameController.text = medication.name;
      _dosageController.text = medication.dosageInstructions;
      _scheduleController.text = medication.schedule;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _scheduleController.dispose();
    super.dispose();
  }

  bool _validate() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a medication name')),
      );
      return false;
    }
    if (_scheduleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter at least one time (e.g. 08:00, 20:00)'),
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _save() async {
    if (!_validate()) return;
    setState(() => _isSaving = true);

    final medication = Medication(
      id: widget.medication?.id ?? _newId(),
      name: _nameController.text.trim(),
      dosageInstructions: _dosageController.text.trim(),
      schedule: _scheduleController.text.trim(),
      startDate: DateTime.now(),
      endDate: null,
      active: true,
    );

    await ref
        .read(medicationControllerProvider)
        .saveMedication(medication, remindMe: _remindMe);

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
    final isEditing = widget.medication != null;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppTopBar(
        title: isEditing ? 'Edit Medication' : 'Add Medication',
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
                    'Medication Name',
                    style: AppTypography.labelMedium.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const ValueKey('medication-name-field'),
                    controller: _nameController,
                    style: AppTypography.bodyMedium,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Lisinopril 10mg',
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Dosage Instructions',
                    style: AppTypography.labelMedium.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const ValueKey('medication-dosage-field'),
                    controller: _dosageController,
                    style: AppTypography.bodyMedium,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Take one tablet by mouth',
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Schedule Times',
                    style: AppTypography.labelMedium.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const ValueKey('medication-schedule-field'),
                          controller: _scheduleController,
                          style: AppTypography.bodyMedium,
                          decoration: InputDecoration(
                            hintText: '08:00, 20:00',
                            suffixText: 'HH:MM',
                            suffixStyle: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                            );
                            if (time != null && mounted) {
                              final current = _scheduleController.text;
                              final newTime =
                                  '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                              _scheduleController.text =
                                  current.isEmpty
                                      ? newTime
                                      : '$current, $newTime';
                            }
                          },
                          readOnly: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Material(
                    color: Colors.transparent,
                    child: SwitchListTile(
                      key: const ValueKey('medication-remind-switch'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Remind me at these times',
                        style: AppTypography.labelLarge.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        'Uses local notifications. You can change this later '
                        'from the reminders list.',
                        style: AppTypography.bodySmall.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      value: _remindMe,
                      onChanged: (value) =>
                          setState(() => _remindMe = value),
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
                  label: isEditing ? 'Update Medication' : 'Add Medication',
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
