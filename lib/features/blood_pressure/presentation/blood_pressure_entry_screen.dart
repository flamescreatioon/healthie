/// The blood-pressure entry screen.
///
/// This screen carries the app's only safety-critical interaction. The
/// classification and the safety guidance are evaluated from the values as
/// they are typed, and the safety alert operates on the individual reading —
/// never on an average, never on a trend.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/units/unit.dart';
import '../../../core/utils/date_range.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/id_generator.dart';
import '../../../shared/form/entry_widgets.dart';
import '../../../shared/formatters/value_formatter.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_top_bar.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/selectors.dart';
import '../../../shared/widgets/states.dart';
import '../../metrics/domain/blood_pressure_guideline.dart';
import '../../metrics/domain/measurement.dart';
import '../../metrics/domain/metric_type.dart';
import '../../metrics/domain/reading_context.dart';
import '../../metrics/presentation/providers/measurement_providers.dart';

/// Records a blood-pressure reading.
class BloodPressureEntryScreen extends ConsumerStatefulWidget {
  const BloodPressureEntryScreen({super.key, this.existing});

  /// The record being edited, or null when recording a new one.
  final Measurement? existing;

  @override
  ConsumerState<BloodPressureEntryScreen> createState() =>
      _BloodPressureEntryScreenState();
}

class _BloodPressureEntryScreenState
    extends ConsumerState<BloodPressureEntryScreen> {
  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _pulseController = TextEditingController();
  final _notesController = TextEditingController();

  BodyPosture _posture = BodyPosture.sitting;
  MeasurementArm _arm = MeasurementArm.left;
  final Set<ReadingCircumstance> _circumstances = {ReadingCircumstance.resting};
  DateTime _timestamp = DateTime.now();
  bool _guidanceExpanded = true;
  bool _isSaving = false;
  String? _systolicError;
  String? _diastolicError;
  String? _pulseError;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _systolicController.text = formatValue(existing.value);
      _diastolicController.text =
          existing.secondaryValue == null ? '' : formatValue(existing.secondaryValue!);
      _pulseController.text =
          existing.tertiaryValue == null ? '' : formatValue(existing.tertiaryValue!);
      _notesController.text = existing.context.notes ?? '';
      _posture = existing.context.posture ?? BodyPosture.sitting;
      _arm = existing.context.arm ?? MeasurementArm.left;
      _circumstances
        ..clear()
        ..addAll(existing.context.circumstances);
      _timestamp = existing.recordedAt.toLocal();
    } else {
      _fetchLastReading();
    }
    _systolicController.addListener(_onValueChanged);
    _diastolicController.addListener(_onValueChanged);
    _pulseController.addListener(_onValueChanged);
  }

  Measurement? _lastReading;

  Future<void> _fetchLastReading() async {
    final latest = await ref
        .read(measurementRepositoryProvider)
        .latestOf(MetricType.bloodPressure);
    if (latest == null || !mounted) return;
    setState(() => _lastReading = latest);
  }

  @override
  void dispose() {
    _systolicController.dispose();
    _diastolicController.dispose();
    _pulseController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onValueChanged() => setState(() {});

  int? get _systolic =>
      parseNumeric(_systolicController.text)?.round();

  int? get _diastolic =>
      parseNumeric(_diastolicController.text)?.round();

  int? get _pulse => parseNumeric(_pulseController.text)?.round();

  BpCategory? get _category {
    final systolic = _systolic;
    final diastolic = _diastolic;
    if (systolic == null || diastolic == null) return null;
    return classifyBloodPressure(systolic: systolic, diastolic: diastolic);
  }

  BpSafetyAssessment get _safety {
    return assessBloodPressureSafety(
      systolic: _systolic,
      diastolic: _diastolic,
    );
  }

  Future<void> _adjust(TextEditingController controller, int delta) async {
    final parsed = parseNumeric(controller.text);
    // Stepping up from an empty field starts from a conventional value, which
    // is an explicit user action rather than a silent default.
    final current = parsed ?? _steppingDefault(controller);
    final next = (current + delta).clamp(0, 999);
    controller.text = formatValue(next.toDouble());
  }

  double _steppingDefault(TextEditingController controller) {
    if (identical(controller, _systolicController)) return 120;
    if (identical(controller, _diastolicController)) return 80;
    return 70;
  }

  bool _validate() {
    final spec = MetricCatalog.bloodPressure;
    final systolic = _systolic;
    final diastolic = _diastolic;
    final pulse = _pulse;

    setState(() {
      _systolicError = (systolic == null ||
              systolic < spec.min ||
              systolic > spec.max)
          ? 'Enter a systolic value between ${spec.min.round()} and '
              '${spec.max.round()} mmHg'
          : null;
      _diastolicError = (diastolic == null ||
              diastolic < spec.secondary!.min ||
              diastolic > spec.secondary!.max)
          ? 'Enter a diastolic value between '
              '${spec.secondary!.min.round()} and '
              '${spec.secondary!.max.round()} mmHg'
          : null;

      if (_systolicError == null &&
          _diastolicError == null &&
          systolic != null &&
          diastolic != null) {
        if (systolic <= diastolic) {
          _systolicError = 'Systolic must be higher than diastolic';
        } else if ((systolic - diastolic) < 15) {
          _diastolicError =
              'Pulse pressure (systolic - diastolic) is implausibly narrow (< 15 mmHg)';
        }
      }

      _pulseError = (pulse != null &&
              (pulse < spec.tertiary!.min || pulse > spec.tertiary!.max))
          ? 'Enter a pulse between ${spec.tertiary!.min.round()} and '
              '${spec.tertiary!.max.round()} bpm'
          : null;
    });

    return _systolicError == null &&
        _diastolicError == null &&
        _pulseError == null;
  }

  Future<void> _save({required bool addAnother}) async {
    if (!_validate()) return;
    final systolic = _systolic!;
    final diastolic = _diastolic!;
    final pulse = _pulse;

    // Hypertensive Crisis confirmation if extreme readings are entered
    if (_safety.level == BpSafetyLevel.urgent && !addAnother) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(
            Icons.warning_amber_rounded,
            color: Theme.of(ctx).colorScheme.error,
            size: 36,
          ),
          title: const Text('Hypertensive Crisis Advisory'),
          content: const Text(
            'This reading exceeds 180 systolic or 120 diastolic. '
            'If you are experiencing acute symptoms like chest pain, shortness of breath, '
            'or severe headache, seek immediate emergency medical care.\n\n'
            'Do you want to record this reading now?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Re-measure'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Confirm & Save'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    setState(() => _isSaving = true);
    final repository = ref.read(measurementRepositoryProvider);
    final clock = ref.read(clockProvider);
    final now = clock.now();
    final existing = widget.existing;

    final measurement = Measurement(
      id: existing?.id ?? newId(),
      metricType: MetricType.bloodPressure,
      value: systolic.toDouble(),
      unit: Unit.millimetreOfMercury,
      secondaryValue: diastolic.toDouble(),
      secondaryUnit: Unit.millimetreOfMercury,
      tertiaryValue: pulse?.toDouble(),
      tertiaryUnit: pulse == null ? null : Unit.beatsPerMinute,
      recordedAt: _timestamp.toUtc(),
      localDay: startOfLocalDay(_timestamp),
      createdAt: existing?.createdAt ?? now.toUtc(),
      updatedAt: now.toUtc(),
      source: existing?.source ?? MeasurementSource.manual,
      isSynced: false,
      context: MeasurementContext(
        posture: _posture,
        arm: _arm,
        circumstances: Set.of(_circumstances),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      ),
    );

    try {
      await repository.save(measurement);
    } on Object {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't save your entry. Your data is still here — try again.",
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (addAnother) {
      _systolicController.clear();
      _diastolicController.clear();
      _pulseController.clear();
      setState(() {
        _systolicError = null;
        _diastolicError = null;
        _pulseError = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reading recorded. Ready for next entry.'),
        ),
      );
      return;
    }
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = _category;
    final safety = _safety;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppTopBar(
        title: 'Vital Entry Sheet',
        icon: Icons.favorite_rounded,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  if (safety.level == BpSafetyLevel.urgent) ...[
                    _SafetyCard(assessment: safety),
                    const SizedBox(height: 16),
                  ],
                  if (_lastReading != null) ...[
                    _PreviousReadingChip(
                      reading: _lastReading!,
                      onCopy: () {
                        setState(() {
                          _systolicController.text = formatValue(_lastReading!.value);
                          if (_lastReading!.secondaryValue != null) {
                            _diastolicController.text = formatValue(_lastReading!.secondaryValue!);
                          }
                          if (_lastReading!.tertiaryValue != null) {
                            _pulseController.text = formatValue(_lastReading!.tertiaryValue!);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  _GuidanceBanner(
                    expanded: _guidanceExpanded,
                    onToggle: () =>
                        setState(() => _guidanceExpanded = !_guidanceExpanded),
                  ),
                  const SizedBox(height: 16),
                  _ReadingCard(
                    systolicController: _systolicController,
                    diastolicController: _diastolicController,
                    pulseController: _pulseController,
                    systolicError: _systolicError,
                    diastolicError: _diastolicError,
                    pulseError: _pulseError,
                    onAdjust: _adjust,
                    category: category,
                    onCategoryChanged: _onValueChanged,
                  ),
                  const SizedBox(height: 16),
                  if (safety.level != BpSafetyLevel.urgent) ...[
                    _SafetyCard(assessment: safety),
                    const SizedBox(height: 16),
                  ],
                  _ContextCard(
                    timestamp: _timestamp,
                    onTimestampChanged: (value) =>
                        setState(() => _timestamp = value),
                    posture: _posture,
                    onPostureChanged: (value) =>
                        setState(() => _posture = value),
                    arm: _arm,
                    onArmChanged: (value) => setState(() => _arm = value),
                    circumstances: _circumstances,
                    onCircumstanceToggled: (value) {
                      setState(() {
                        if (!_circumstances.remove(value)) {
                          _circumstances.add(value);
                        }
                      });
                    },
                    notesController: _notesController,
                  ),
                  const SizedBox(height: 16),
                  const _RecentTrendCard(),
                  const SizedBox(height: 16),
                  const _DisclaimerFooter(),
                ],
              ),
            ),
            _SaveBar(
              isSaving: _isSaving,
              onSave: () => _save(addAnother: false),
              onSaveAndAddAnother: () => _save(addAnother: true),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuidanceBanner extends StatelessWidget {
  const _GuidanceBanner({required this.expanded, required this.onToggle});

  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.favorite_rounded,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Pre-Check Guidance',
                        style: AppTypography.headlineSmall
                            .copyWith(color: theme.colorScheme.onSurface),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        '5 min rest',
                        style: AppTypography.labelMicro.copyWith(
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                if (expanded) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Rest quietly for 5 minutes. Keep your back supported, feet '
                    'flat on the ground, and your arm resting naturally at '
                    'heart level.',
                    style: AppTypography.bodySmall.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: expanded ? 'Collapse guidance' : 'Expand guidance',
            icon: Icon(
              expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              size: 20,
            ),
            onPressed: onToggle,
          ),
        ],
      ),
    );
  }
}

class _ReadingCard extends StatelessWidget {
  const _ReadingCard({
    required this.systolicController,
    required this.diastolicController,
    required this.pulseController,
    required this.systolicError,
    required this.diastolicError,
    required this.pulseError,
    required this.onAdjust,
    required this.category,
    required this.onCategoryChanged,
  });

  final TextEditingController systolicController;
  final TextEditingController diastolicController;
  final TextEditingController pulseController;
  final String? systolicError;
  final String? diastolicError;
  final String? pulseError;
  final Future<void> Function(TextEditingController controller, int delta)
      onAdjust;
  final BpCategory? category;
  final VoidCallback onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.monitor_heart_rounded,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Blood Pressure Reading',
                  style: AppTypography.labelLarge
                      .copyWith(color: theme.colorScheme.onSurface),
                ),
              ),
              StatusPill(
                label: 'Dual scrubber',
                tone: StatusTone.neutral,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ValueTile(
                  label: 'Systolic',
                  controller: systolicController,
                  unit: 'mmHg',
                  error: systolicError,
                  onDecrement: () => onAdjust(systolicController, -1),
                  onIncrement: () => onAdjust(systolicController, 1),
                  onChanged: onCategoryChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ValueTile(
                  label: 'Diastolic',
                  controller: diastolicController,
                  unit: 'mmHg',
                  error: diastolicError,
                  onDecrement: () => onAdjust(diastolicController, -1),
                  onIncrement: () => onAdjust(diastolicController, 1),
                  onChanged: onCategoryChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.favorite_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Resting Heart Rate',
                        style: AppTypography.labelMedium
                            .copyWith(color: theme.colorScheme.onSurface),
                      ),
                      Text(
                        'Optional companion metric',
                        style: AppTypography.bodySmall.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: TextField(
                    key: const ValueKey('pulse-field'),
                    controller: pulseController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.right,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: (_) => onCategoryChanged(),
                    style: AppTypography.headlineMedium.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      errorText: pulseError,
                      suffixText: 'bpm',
                      suffixStyle: AppTypography.bodySmall.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ClassificationPill(category: category),
        ],
      ),
    );
  }
}

class _ValueTile extends StatelessWidget {
  const _ValueTile({
    required this.label,
    required this.controller,
    required this.unit,
    required this.error,
    required this.onDecrement,
    required this.onIncrement,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String unit;
  final String? error;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: AppTypography.labelMicro.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: TextField(
                  key: ValueKey('value-field-$label'),
                  controller: controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => onChanged(),
                  style: AppTypography.displayNumeric.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: AppTypography.bodySmall
                    .copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                error!,
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StepButton(
                icon: Icons.remove_rounded,
                tooltip: 'Decrease $label',
                onPressed: onDecrement,
              ),
              const SizedBox(width: 12),
              _StepButton(
                icon: Icons.add_rounded,
                tooltip: 'Increase $label',
                onPressed: onIncrement,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: theme.colorScheme.surfaceContainerLowest,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Center(
              child: SizedBox(
                width: 36,
                height: 36,
                child: Icon(icon, size: 18, color: theme.colorScheme.onSurface),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClassificationPill extends StatelessWidget {
  const _ClassificationPill({required this.category});

  final BpCategory? category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);

    final (String label, StatusTone tone, IconData icon) = switch (category) {
      null => ('Enter both values', StatusTone.neutral, Icons.info_rounded),
      BpCategory.normal => ('Normal range', StatusTone.positive, Icons.check_circle_rounded),
      BpCategory.elevated => ('Elevated', StatusTone.warning, Icons.trending_up_rounded),
      BpCategory.stage1Hypertension => (
          'Stage 1 hypertension',
          StatusTone.warning,
          Icons.info_rounded
        ),
      BpCategory.stage2Hypertension => (
          'Stage 2 hypertension',
          StatusTone.critical,
          Icons.warning_rounded
        ),
      BpCategory.hypertensiveCrisis => (
          'Hypertensive crisis — seek care',
          StatusTone.critical,
          Icons.emergency_rounded
        ),
    };


    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: switch (tone) {
          StatusTone.positive => colors.positive.withValues(alpha: 0.10),
          StatusTone.warning => colors.warning.withValues(alpha: 0.12),
          StatusTone.critical => colors.critical.withValues(alpha: 0.10),
          _ => theme.colorScheme.surfaceContainerLow,
        },
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _foreground(context, tone)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: AppTypography.labelMedium
                  .copyWith(color: theme.colorScheme.onSurface),
            ),
          ),
          Text(
            defaultBpGuideline.name,
            style: AppTypography.labelMicro.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  static Color _foreground(BuildContext context, StatusTone tone) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    return switch (tone) {
      StatusTone.positive => colors.positive,
      StatusTone.warning => colors.warning,
      StatusTone.critical => colors.critical,
      StatusTone.primary => theme.colorScheme.primary,
      StatusTone.neutral => theme.colorScheme.onSurfaceVariant,
    };
  }
}

class _ContextCard extends StatelessWidget {
  const _ContextCard({
    required this.timestamp,
    required this.onTimestampChanged,
    required this.posture,
    required this.onPostureChanged,
    required this.arm,
    required this.onArmChanged,
    required this.circumstances,
    required this.onCircumstanceToggled,
    required this.notesController,
  });

  final DateTime timestamp;
  final ValueChanged<DateTime> onTimestampChanged;
  final BodyPosture posture;
  final ValueChanged<BodyPosture> onPostureChanged;
  final MeasurementArm arm;
  final ValueChanged<MeasurementArm> onArmChanged;
  final Set<ReadingCircumstance> circumstances;
  final ValueChanged<ReadingCircumstance> onCircumstanceToggled;
  final TextEditingController notesController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DateTimeSelector(value: timestamp, onChanged: onTimestampChanged),
          const SizedBox(height: 20),
          Text(
            'Posture',
            style: AppTypography.labelMedium
                .copyWith(color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 8),
          SegmentedControl<BodyPosture>(
            options: BodyPosture.values,
            selected: posture,
            onChanged: onPostureChanged,
            labelBuilder: (option) => option.label,
          ),
          const SizedBox(height: 20),
          Text(
            'Measurement Arm',
            style: AppTypography.labelMedium
                .copyWith(color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 8),
          SegmentedControl<MeasurementArm>(
            options: MeasurementArm.values,
            selected: arm,
            onChanged: onArmChanged,
            labelBuilder: (option) => option.label,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Circumstance & Activity',
                  style: AppTypography.labelMedium
                      .copyWith(color: theme.colorScheme.onSurface),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  'Select all applicable',
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall
                      .copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final circumstance in ReadingCircumstance.values)
                SelectableChip(
                  label: circumstance.label,
                  selected: circumstances.contains(circumstance),
                  onChanged: (_) => onCircumstanceToggled(circumstance),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Notes & Observations',
                  style: AppTypography.labelMedium
                      .copyWith(color: theme.colorScheme.onSurface),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  'Optional',
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall
                      .copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('bp-notes-field'),
            controller: notesController,
            maxLines: 2,
            style: AppTypography.bodyMedium,
            decoration: const InputDecoration(
              hintText: 'e.g., Felt relaxed, taken before morning espresso…',
            ),
          ),
        ],
      ),
    );
  }
}

class _SafetyCard extends StatelessWidget {
  const _SafetyCard({required this.assessment});

  final BpSafetyAssessment assessment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final urgent = assessment.level == BpSafetyLevel.urgent;
    final caution = assessment.level == BpSafetyLevel.caution;

    final background = urgent
        ? colors.critical.withValues(alpha: 0.10)
        : caution
            ? colors.warning.withValues(alpha: 0.10)
            : theme.colorScheme.surfaceContainerLow;
    final foreground = urgent
        ? colors.critical
        : caution
            ? colors.warning
            : theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: foreground.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            urgent ? Icons.emergency_rounded : Icons.verified_user_rounded,
            size: 20,
            color: foreground,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assessment.headline,
                  style: AppTypography.labelLarge
                      .copyWith(color: theme.colorScheme.onSurface),
                ),
                const SizedBox(height: 4),
                Text(
                  assessment.guidance,
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
    );
  }
}

class _RecentTrendCard extends ConsumerWidget {
  const _RecentTrendCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final range = DateRange(
      start: startOfLocalDay(now).subtract(const Duration(days: 6)),
      end: startOfLocalDay(now).add(const Duration(days: 1)),
    );
    final readings = ref.watch(
      measurementsByTypeProvider(
        MetricRangeQuery(type: MetricType.bloodPressure, range: range),
      ),
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recent 7-Day Trend',
                  style: AppTypography.labelLarge
                      .copyWith(color: theme.colorScheme.onSurface),
                ),
              ),
              readings.when(
                data: (data) => Text(
                  _averageLabel(data),
                  style: AppTypography.labelMicro.copyWith(
                    color: theme.colorScheme.tertiary,
                  ),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 72,
            child: readings.when(
              data: (data) => _TrendBars(readings: data),
              loading: () => const LoadingState(height: 72, lines: 1),
              error: (_, _) => Text(
                'Could not load the recent trend.',
                style: AppTypography.bodySmall
                    .copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _averageLabel(List<Measurement> data) {
    if (data.isEmpty) return 'No readings';
    final systolic = data.map((m) => m.value).reduce((a, b) => a + b) / data.length;
    final diastolicValues = data
        .map((m) => m.secondaryValue)
        .whereType<double>()
        .toList();
    final diastolic = diastolicValues.isEmpty
        ? null
        : diastolicValues.reduce((a, b) => a + b) / diastolicValues.length;
    return 'AVG ${formatValue(systolic)}'
        '${diastolic == null ? '' : ' / ${formatValue(diastolic)}'}';
  }
}

class _TrendBars extends StatelessWidget {
  const _TrendBars({required this.readings});

  final List<Measurement> readings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final days = List.generate(
      7,
      (index) => startOfLocalDay(now).subtract(Duration(days: 6 - index)),
    );
    final byDay = <DateTime, List<Measurement>>{};
    for (final reading in readings) {
      byDay.putIfAbsent(startOfLocalDay(reading.recordedAt), () => []).add(reading);
    }

    final values = days.map((day) {
      final readingsForDay = byDay[day] ?? const <Measurement>[];
      if (readingsForDay.isEmpty) return null;
      return readingsForDay
              .map((m) => m.value)
              .reduce((a, b) => a + b) /
          readingsForDay.length;
    }).toList();

    final highest = values.whereType<double>().fold<double>(140, (a, b) => a > b ? a : b);
    final lowest = values.whereType<double>().fold<double>(60, (a, b) => a < b ? a : b);
    final span = (highest - lowest).abs() < 1 ? 1.0 : highest - lowest;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < days.length; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    height: values[i] == null
                        ? 6
                        : 12 + (values[i]! - lowest) / span * 42,
                    decoration: BoxDecoration(
                      color: values[i] == null
                          ? theme.colorScheme.surfaceContainerHigh
                          : theme.colorScheme.secondary,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][i],
                    style: AppTypography.labelMicro.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.isSaving,
    required this.onSave,
    required this.onSaveAndAddAnother,
  });

  final bool isSaving;
  final VoidCallback onSave;
  final VoidCallback onSaveAndAddAnother;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.94),
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SaveButton(
              label: 'Save reading',
              isSaving: isSaving,
              onPressed: onSave,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: isSaving ? null : onSaveAndAddAnother,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Save & add another'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviousReadingChip extends StatelessWidget {
  const _PreviousReadingChip({
    required this.reading,
    required this.onCopy,
  });

  final Measurement reading;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sys = formatValue(reading.value);
    final dia = reading.secondaryValue != null
        ? '/${formatValue(reading.secondaryValue!)}'
        : '';
    final pulse = reading.tertiaryValue != null
        ? ' (${formatValue(reading.tertiaryValue!)} bpm)'
        : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.history_rounded,
              size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Previous: $sys$dia mmHg$pulse',
              style: AppTypography.bodySmall.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          InkWell(
            onTap: onCopy,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                'Copy',
                style: AppTypography.labelMedium.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DisclaimerFooter extends StatelessWidget {
  const _DisclaimerFooter();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        'Healthie is for personal health tracking and informational purposes only, '
        'not a substitute for professional medical diagnosis or clinical care.',
        textAlign: TextAlign.center,
        style: AppTypography.labelMicro.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
    );
  }
}

