/// Reusable selectors: date ranges, chips, and metric badges.
library;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

/// A range of history the user can analyse.
enum AnalysisRange {
  sevenDays('7 days', 7),
  thirtyDays('30 days', 30),
  ninetyDays('90 days', 90),
  sixMonths('6 months', 182),
  oneYear('1 year', 365),
  all('All', 3650);

  const AnalysisRange(this.label, this.days);

  /// The label shown on the selector.
  final String label;

  /// How many days the range covers. `all` uses a deliberately large window.
  final int days;
}

/// A horizontal segmented control for choosing a range.
class RangeSelector extends StatelessWidget {
  const RangeSelector({
    required this.selected,
    required this.onChanged,
    super.key,
    this.options = const [
      AnalysisRange.sevenDays,
      AnalysisRange.thirtyDays,
      AnalysisRange.ninetyDays,
      AnalysisRange.sixMonths,
      AnalysisRange.oneYear,
      AnalysisRange.all,
    ],
  });

  /// The currently selected range.
  final AnalysisRange selected;

  /// Called when the user picks a different range.
  final ValueChanged<AnalysisRange> onChanged;

  /// The ranges to offer.
  final List<AnalysisRange> options;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Time range',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            for (final option in options) ...[
              _RangeChip(
                label: option.label,
                selected: option == selected,
                onTap: () => onChanged(option),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? theme.colorScheme.primary
            : theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 8,
            ),
            child: Text(
              label,
              style: AppTypography.labelMedium.copyWith(
                color: selected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A chip that can be toggled on or off.
class SelectableChip extends StatelessWidget {
  const SelectableChip({
    required this.label,
    required this.selected,
    required this.onChanged,
    super.key,
    this.icon,
  });

  /// The chip's label.
  final String label;

  /// Whether the chip is currently selected.
  final bool selected;

  /// Called with the new selection state.
  final ValueChanged<bool> onChanged;

  /// An optional leading icon.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? theme.colorScheme.primary
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          onTap: () => onChanged(!selected),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 9,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[
                  Icon(
                    Icons.check_rounded,
                    size: 15,
                    color: theme.colorScheme.onPrimary,
                  ),
                  const SizedBox(width: 5),
                ] else if (icon != null) ...[
                  Icon(icon, size: 15, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 5),
                ],
                Text(
                  label,
                  style: AppTypography.labelMedium.copyWith(
                    color: selected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A segmented control for choosing one option from a small set.
class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({
    required this.options,
    required this.selected,
    required this.onChanged,
    super.key,
    this.labelBuilder,
  });

  /// The options, in display order.
  final List<T> options;

  /// The currently selected option.
  final T selected;

  /// Called with the newly selected option.
  final ValueChanged<T> onChanged;

  /// Builds a label for an option.
  final String Function(T option)? labelBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        child: Row(
          children: [
            for (final option in options)
              Expanded(
                child: _Segment<T>(
                  label: labelBuilder?.call(option) ?? option.toString(),
                  selected: option == selected,
                  onTap: () => onChanged(option),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Segment<T> extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? theme.colorScheme.surfaceContainerLowest
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.control - 2),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.control - 2),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppTypography.labelMedium.copyWith(
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A metric's icon and fixed accent colour.
class MetricBadge extends StatelessWidget {
  const MetricBadge({
    required this.icon,
    required this.color,
    super.key,
    this.size = 40,
  });

  /// The icon.
  final IconData icon;

  /// The metric's fixed accent.
  final Color color;

  /// The diameter of the badge.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: size * 0.5, color: color),
    );
  }
}

/// Reads the fixed accent colour for a metric from the theme.
extension MetricAccents on BuildContext {
  AppColors get metricColors => Theme.of(this).extension<AppColors>()!;
}
