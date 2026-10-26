/// The body-weight entry screen.
///
/// Weight is stored in kilograms. The unit toggle converts the current value
/// in place, so switching from kilograms to pounds shows the same weight in
/// pounds rather than reinterpreting the number.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/units/unit.dart';
import '../../../core/utils/date_range.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/id_generator.dart';
import '../../../features/analytics/domain/weight_analytics.dart';
import '../../../features/metrics/domain/measurement.dart';
import '../../../features/metrics/domain/metric_type.dart';
import '../../../features/metrics/domain/reading_context.dart';
import '../../../features/metrics/presentation/providers/measurement_providers.dart';
import '../../../features/profile/domain/health_profile.dart';
import '../../../features/profile/presentation/providers/profile_providers.dart';
import '../../../shared/form/entry_widgets.dart';
import '../../../shared/formatters/value_formatter.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_top_bar.dart';
import '../../../shared/widgets/selectors.dart';

/// Records a body-weight reading.
class WeightEntryScreen extends ConsumerStatefulWidget {
  const WeightEntryScreen({super.key, this.existing});

  /// The record being edited, or null when recording a new one.
  final Measurement? existing;

  @override
  ConsumerState<WeightEntryScreen> createState() => _WeightEntryScreenState();
}

class _WeightEntryScreenState extends ConsumerState<WeightEntryScreen> {
  final _weightController = TextEditingController();
  final _bodyFatController = TextEditingController();
  final _waistController = TextEditingController();
  final _notesController = TextEditingController();

  Unit _displayUnit = Unit.kilogram;
  double? _canonicalKg;
  WeightTimeOfDay _timeOfDay = WeightTimeOfDay.morningFasting;
  DateTime _timestamp = DateTime.now();
  bool _compositionExpanded = false;
  bool _isSaving = false;
  String? _weightError;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _canonicalKg = existing.value;
      _weightController.text = formatValue(existing.value, precision: 1);
      _bodyFatController.text = existing.bodyFatPercent == null
          ? ''
          : formatValue(existing.bodyFatPercent!, precision: 1);
      _waistController.text = existing.waistCircumference == null
          ? ''
          : formatValue(existing.waistCircumference!, precision: 1);
      _notesController.text = existing.context.notes ?? '';
      _timeOfDay = existing.context.weightTimeOfDay ?? WeightTimeOfDay.morningFasting;
      _timestamp = existing.recordedAt.toLocal();
    }
    _weightController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _weightController.dispose();
    _bodyFatController.dispose();
    _waistController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _setUnit(Unit unit) {
    if (unit == _displayUnit) return;
    setState(() {
      _displayUnit = unit;
      if (_canonicalKg != null) {
        final displayVal = unit == Unit.pound
            ? convert(_canonicalKg!, Unit.kilogram, Unit.pound)
            : _canonicalKg!;
        _weightController.text = formatValue(displayVal, precision: 1);
      }
    });
  }

  void _adjust(double delta) {
    final spec = MetricCatalog.weight;
    final currentDisplay = double.tryParse(_weightController.text.trim()) ??
        (_canonicalKg != null
            ? (_displayUnit == Unit.pound
                ? convert(_canonicalKg!, Unit.kilogram, Unit.pound)
                : _canonicalKg!)
            : (_displayUnit == Unit.pound
                ? convert(70, Unit.kilogram, Unit.pound)
                : 70.0));

    final nextDisplay = currentDisplay + delta;
    final nextKg = _displayUnit == Unit.pound
        ? convert(nextDisplay, Unit.pound, Unit.kilogram)
        : nextDisplay;

    final clampedKg = nextKg.clamp(spec.min, spec.max);
    final finalDisplay = _displayUnit == Unit.pound
        ? convert(clampedKg, Unit.kilogram, Unit.pound)
        : clampedKg;

    setState(() {
      _canonicalKg = clampedKg;
      _weightController.text = formatValue(finalDisplay, precision: 1);
      _weightError = null;
    });
  }

  void _onWeightTyped(String text) {
    final parsed = parseNumeric(text);
    if (parsed == null) {
      setState(() => _canonicalKg = null);
      return;
    }
    setState(() {
      _canonicalKg = convert(parsed, _displayUnit, Unit.kilogram);
    });
  }

  bool _validate() {
    final spec = MetricCatalog.weight;
    final parsed = parseNumeric(_weightController.text);
    double? kg;
    if (parsed != null) {
      if (_canonicalKg != null &&
          roundTo(convert(_canonicalKg!, Unit.kilogram, _displayUnit), 1) ==
              roundTo(parsed, 1)) {
        kg = _canonicalKg;
      } else {
        kg = convert(parsed, _displayUnit, Unit.kilogram);
      }
    }
    setState(() {
      if (kg == null) {
        _weightError = 'Please enter your weight';
      } else if (kg < spec.min || kg > spec.max) {
        final minDisplay = _displayUnit == Unit.pound
            ? convert(spec.min, Unit.kilogram, Unit.pound).round()
            : spec.min.round();
        final maxDisplay = _displayUnit == Unit.pound
            ? convert(spec.max, Unit.kilogram, Unit.pound).round()
            : spec.max.round();
        _weightError = 'Enter a weight between $minDisplay and '
            '$maxDisplay ${_displayUnit.symbol}';
      } else {
        _weightError = null;
        _canonicalKg = kg;
      }
    });
    return _weightError == null;
  }

  Future<void> _save() async {
    if (!_validate()) return;
    final repository = ref.read(measurementRepositoryProvider);
    final clock = ref.read(clockProvider);
    final now = clock.now();
    final existing = widget.existing;

    final bodyFat = parseNumeric(_bodyFatController.text);
    final waist = parseNumeric(_waistController.text);

    final measurement = Measurement(
      id: existing?.id ?? newId(),
      metricType: MetricType.weight,
      value: roundTo(_canonicalKg!, 2),
      unit: Unit.kilogram,
      secondaryValue: bodyFat,
      secondaryUnit: bodyFat == null ? null : Unit.percent,
      tertiaryValue: waist,
      tertiaryUnit: waist == null ? null : Unit.centimetre,
      recordedAt: _timestamp.toUtc(),
      localDay: startOfLocalDay(_timestamp),
      createdAt: existing?.createdAt ?? now.toUtc(),
      updatedAt: now.toUtc(),
      source: existing?.source ?? MeasurementSource.manual,
      isSynced: false,
      context: MeasurementContext(
        weightTimeOfDay: _timeOfDay,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      ),
    );

    setState(() => _isSaving = true);
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
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(profileProvider).value;
    final goals = ref.watch(goalsProvider).value ?? const <HealthGoal>[];
    final weightGoal = goals
        .where((goal) => goal.metricType == MetricType.weight.wireName)
        .firstOrNull;

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
                  const _PreviousEntryBanner(),
                  const SizedBox(height: 16),
                  _WeightDialCard(
                    controller: _weightController,
                    displayUnit: _displayUnit,
                    error: _weightError,
                    onUnitChanged: _setUnit,
                    onDecrement: () => _adjust(-0.1),
                    onIncrement: () => _adjust(0.1),
                    onTyped: _onWeightTyped,
                  ),
                  const SizedBox(height: 16),
                  const _WellnessNote(),
                  const SizedBox(height: 16),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Log Conditions',
                                style: AppTypography.headlineSmall
                                    .copyWith(color: theme.colorScheme.onSurface),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        DateTimeSelector(
                          value: _timestamp,
                          onChanged: (value) => setState(() => _timestamp = value),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Time of Day',
                          style: AppTypography.labelMedium
                              .copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final slot in WeightTimeOfDay.values)
                              SelectableChip(
                                label: slot.label,
                                selected: _timeOfDay == slot,
                                onChanged: (_) =>
                                    setState(() => _timeOfDay = slot),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Notes (Optional)',
                          style: AppTypography.labelMedium
                              .copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          key: const ValueKey('weight-notes-field'),
                          controller: _notesController,
                          style: AppTypography.bodyMedium,
                          decoration: const InputDecoration(
                            hintText:
                                'E.g., Felt well-rested, after morning jog…',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _CompositionCard(
                    expanded: _compositionExpanded,
                    bodyFatController: _bodyFatController,
                    waistController: _waistController,
                    onToggle: () => setState(
                      () => _compositionExpanded = !_compositionExpanded,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (weightGoal != null && _canonicalKg != null)
                    _GoalCard(
                      goal: weightGoal,
                      currentKg: _canonicalKg!,
                      startKg: profile == null ? null : null,
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.94),
                border: Border(
                  top: BorderSide(
                    color:
                        theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: SaveButton(
                  label: 'Save weight reading',
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

class _PreviousEntryBanner extends ConsumerWidget {
  const _PreviousEntryBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final range = DateRange.endingOn(DateTime.now(), 3650);
    final readings = ref.watch(
      measurementsByTypeProvider(
        MetricRangeQuery(type: MetricType.weight, range: range),
      ),
    );

    return readings.when(
      data: (data) {
        if (data.isEmpty) return const SizedBox.shrink();
        final latest = data.first;
        final previous = data.length > 1 ? data[1] : null;
        final delta = previous == null ? null : latest.value - previous.value;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.history_rounded,
                  size: 20,
                  color: theme.colorScheme.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Previous entry'.toUpperCase(),
                      style: AppTypography.labelMicro.copyWith(
                        color: theme.colorScheme.outline,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      '${formatValue(latest.value, precision: 1)} kg on '
                      '${shortDateLabel(latest.recordedAt)}',
                      style: AppTypography.bodySmall
                          .copyWith(color: theme.colorScheme.onSurface),
                    ),
                  ],
                ),
              ),
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
                  child: Text(
                    '${formatSigned(delta, precision: 1)} kg',
                    style: AppTypography.labelMicro.copyWith(
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _WeightDialCard extends StatelessWidget {
  const _WeightDialCard({
    required this.controller,
    required this.displayUnit,
    required this.error,
    required this.onUnitChanged,
    required this.onDecrement,
    required this.onIncrement,
    required this.onTyped,
  });

  final TextEditingController controller;
  final Unit displayUnit;
  final String? error;
  final ValueChanged<Unit> onUnitChanged;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final ValueChanged<String> onTyped;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          UnitToggle(
            units: const [Unit.kilogram, Unit.pound],
            selected: displayUnit,
            onChanged: onUnitChanged,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _DialButton(
                icon: Icons.remove_rounded,
                tooltip: 'Decrease weight',
                onPressed: onDecrement,
              ),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: TextField(
                            key: const ValueKey('weight-value-field'),
                            controller: controller,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textAlign: TextAlign.center,
                            onChanged: onTyped,
                            style: AppTypography.displayNumeric.copyWith(
                              color: theme.colorScheme.onSurface,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              contentPadding: EdgeInsets.zero,
                              hintText: displayUnit == Unit.pound ? '154.0' : '70.0',
                              errorText: null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          displayUnit.symbol,
                          style: AppTypography.headlineSmall.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                    if (error != null)
                      Text(
                        error!,
                        textAlign: TextAlign.center,
                        style: AppTypography.bodySmall
                            .copyWith(color: theme.colorScheme.error),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap +/- or nudge',
                      style: AppTypography.labelMicro.copyWith(
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              _DialButton(
                icon: Icons.add_rounded,
                tooltip: 'Increase weight',
                onPressed: onIncrement,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 7; i++)
                Container(
                  width: 2,
                  height: i == 3 ? 28 : (i.isEven ? 20 : 12),
                  decoration: BoxDecoration(
                    color: i == 3
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DialButton extends StatelessWidget {
  const _DialButton({
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
        color: theme.colorScheme.surfaceContainerLow,
        shape: CircleBorder(
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon, size: 24, color: theme.colorScheme.onSurface),
          ),
        ),
      ),
    );
  }
}

class _WellnessNote extends StatelessWidget {
  const _WellnessNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: theme.colorScheme.tertiary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.spa_rounded,
            size: 18,
            color: theme.colorScheme.tertiary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gentle Wellness Note',
                  style: AppTypography.labelMedium.copyWith(
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Healthy fluctuations between 0.5 – 1.5 kg per day are '
                  'completely normal and often driven by hydration, sleep, and '
                  'meal timing.',
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

class _CompositionCard extends StatelessWidget {
  const _CompositionCard({
    required this.expanded,
    required this.bodyFatController,
    required this.waistController,
    required this.onToggle,
  });

  final bool expanded;
  final TextEditingController bodyFatController;
  final TextEditingController waistController;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.accessibility_new_rounded,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Body Composition',
                          style: AppTypography.labelLarge
                              .copyWith(color: theme.colorScheme.onSurface),
                        ),
                        Text(
                          'Fat %, waist, and muscle metrics',
                          style: AppTypography.bodySmall
                              .copyWith(color: theme.colorScheme.outline),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: theme.colorScheme.outline,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const ValueKey('body-fat-field'),
                          controller: bodyFatController,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Body Fat',
                            suffixText: '%',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          key: const ValueKey('waist-field'),
                          controller: waistController,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Waist',
                            suffixText: 'cm',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.currentKg,
    required this.startKg,
  });

  final HealthGoal goal;
  final double currentKg;
  final double? startKg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = startKg == null
        ? null
        : computeGoalProgress(
            target: goal.targetValue,
            current: currentKg,
            start: startKg!,
          );
    final remaining =
        (goal.targetValue - currentKg).abs();

    return AppCard(
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress?.percentAchieved ?? 0,
                  strokeWidth: 3.5,
                  backgroundColor: theme.colorScheme.surfaceContainerHigh,
                  color: theme.colorScheme.secondary,
                ),
                Icon(
                  Icons.track_changes_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Target Goal: ${formatValue(goal.targetValue, precision: 1)} kg',
                  style: AppTypography.labelLarge
                      .copyWith(color: theme.colorScheme.onSurface),
                ),
                Text(
                  '${formatValue(remaining, precision: 1)} kg remaining to your '
                  'target',
                  style: AppTypography.bodySmall
                      .copyWith(color: theme.colorScheme.outline),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: theme.colorScheme.outline,
          ),
        ],
      ),
    );
  }
}
