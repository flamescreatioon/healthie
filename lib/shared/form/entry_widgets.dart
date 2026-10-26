/// The shared entry-form toolkit.
///
/// Every metric's form is assembled from these so they look and behave the
/// same: the same field spacing, the same unit control, the same error
/// styling, the same save button.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/units/unit.dart';
import '../../core/utils/date_utils.dart';

/// A numeric field with a unit suffix.
///
/// The value is parsed with a locale-tolerant parser, so a decimal comma
/// (`78,4`) is accepted in the many locales that use it. The raw text is kept
/// while the user types; parsing happens on submit.
class NumericField extends StatefulWidget {
  const NumericField({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
    this.unit,
    this.decimals = 1,
    this.helperText,
    this.errorText,
    this.textInputAction = TextInputAction.next,
    this.autofocus = false,
    this.semanticLabel,
  });

  /// The field label.
  final String label;

  /// The current text.
  final String value;

  /// Called with the new text on every edit.
  final ValueChanged<String> onChanged;

  /// The unit shown next to the value.
  final Unit? unit;

  /// How many decimals the metric accepts.
  final int decimals;

  /// Helper text under the field.
  final String? helperText;

  /// The error message, when the field is invalid.
  final String? errorText;

  /// The keyboard action button.
  final TextInputAction textInputAction;

  /// Whether the field takes focus on open.
  final bool autofocus;

  /// A screen-reader label for the value, including the unit.
  final String? semanticLabel;

  @override
  State<NumericField> createState() => _NumericFieldState();
}

class _NumericFieldState extends State<NumericField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant NumericField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep the field in step when the value is changed from outside, for
    // example when the user switches units.
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: AppTypography.labelMedium
              .copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.xs),
        Semantics(
          label: widget.semanticLabel ?? widget.label,
          textField: true,
          child: TextField(
            key: ValueKey('numeric-field-${widget.label}'),
            controller: _controller,
            autofocus: widget.autofocus,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: widget.textInputAction,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^-?[0-9]*[.,]?[0-9]{0,2}')),
            ],
            onChanged: widget.onChanged,
            style: AppTypography.bodyLarge.copyWith(
              color: theme.colorScheme.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            decoration: InputDecoration(
              errorText: widget.errorText,
              helperText: widget.helperText,
              helperMaxLines: 3,
              suffixText: widget.unit?.symbol,
              suffixStyle: AppTypography.bodyMedium
                  .copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ),
      ],
    );
  }
}

/// Parses a numeric input into a double.
///
/// Accepts a decimal comma or point, tolerates thousands separators, and
/// returns null when the text is not a number. A trailing separator is
/// accepted while typing.
///
/// A comma is read as a thousands separator when three or more digits follow
/// it (`1,200`), and as a decimal separator otherwise (`78,4`).
double? parseNumeric(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  var cleaned = trimmed.replaceAll(RegExp(r'\s'), '');

  if (cleaned.contains(',')) {
    final lastComma = cleaned.lastIndexOf(',');
    final digitsAfter = cleaned.length - lastComma - 1;
    final isDecimalComma = digitsAfter > 0 && digitsAfter <= 2;
    cleaned = isDecimalComma
        ? cleaned.replaceAll(',', '.')
        : cleaned.replaceAll(',', '');
  } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(cleaned)) {
    // Thousands separators written with a point: 1.200 means 1200.
    cleaned = cleaned.replaceAll('.', '');
  }

  // A trailing separator means "about to type more".
  if (cleaned.endsWith('.')) cleaned = cleaned.substring(0, cleaned.length - 1);

  return double.tryParse(cleaned);
}

/// A control that switches between the units a metric may be entered in.
///
/// Switching converts the current value in place. Leaving the number
/// unchanged while changing the label would corrupt the record.
class UnitToggle extends StatelessWidget {
  const UnitToggle({
    required this.units,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  /// The units on offer.
  final List<Unit> units;

  /// The selected unit.
  final Unit selected;

  /// Called with the newly selected unit.
  final ValueChanged<Unit> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: 'Unit',
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final unit in units)
              Semantics(
                button: true,
                selected: unit == selected,
                child: Material(
                  color: unit == selected
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: InkWell(
                    onTap: () => onChanged(unit),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      child: Text(
                        unit.symbol,
                        style: AppTypography.labelMedium.copyWith(
                          color: unit == selected
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A control that picks the date and time of a measurement.
///
/// Defaults to now and stays editable — logging last night's reading at 9am
/// is completely normal.
class DateTimeSelector extends StatelessWidget {
  const DateTimeSelector({
    required this.value,
    required this.onChanged,
    super.key,
    this.label = 'Timestamp',
  });

  /// The currently selected moment.
  final DateTime value;

  /// Called with the newly selected moment.
  final ValueChanged<DateTime> onChanged;

  /// The field label.
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelMicro.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Material(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.control),
          child: InkWell(
            onTap: () => _pick(context),
            borderRadius: BorderRadius.circular(AppRadius.control),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _format(value),
                      style: AppTypography.labelLarge
                          .copyWith(color: theme.colorScheme.onSurface),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pick(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: DateTime(value.year - 20),
      lastDate: DateTime(value.year + 1),
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value),
    );
    if (time == null) return;

    onChanged(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  static String _format(DateTime value) {
    final local = value.toLocal();
    final time = timeOfDayLabel(local);
    if (isSameLocalDay(local, DateTime.now())) return 'Today, $time';
    return '${shortDateLabel(local)}, $time';
  }
}

/// A primary action button that disables itself while an action is running,
/// so a double tap cannot create two records.
class SaveButton extends StatelessWidget {
  const SaveButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.isSaving = false,
    this.icon = Icons.check_rounded,
    this.enabled = true,
  });

  /// The button label.
  final String label;

  /// The action.
  final VoidCallback? onPressed;

  /// Whether an action is currently running.
  final bool isSaving;

  /// The leading icon.
  final IconData icon;

  /// Whether the action is available.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: enabled && !isSaving ? onPressed : null,
      icon: isSaving
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 20),
      label: Text(isSaving ? 'Saving…' : label),
    );
  }
}
