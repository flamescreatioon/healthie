/// Section headings and the status pills used across the app.
library;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

/// A section title with an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    super.key,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.only(top: AppSpacing.sm),
  });

  /// The section title.
  final String title;

  /// An optional line under the title.
  final String? subtitle;

  /// An optional trailing widget, such as a link or a pill.
  final Widget? trailing;

  /// Padding around the header.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.headlineSmall
                      .copyWith(color: theme.colorScheme.onSurface),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle!,
                    style: AppTypography.bodySmall
                        .copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// The tone of a status pill.
///
/// A status is never conveyed by colour alone: every pill carries a text
/// label, and the icon reinforces it.
enum StatusTone {
  /// Inside the reference band.
  positive,

  /// Needs attention.
  warning,

  /// Needs prompt action.
  critical,

  /// Informational.
  neutral,

  /// Uses the brand primary.
  primary,
}

/// A pill that labels a status.
class StatusPill extends StatelessWidget {
  const StatusPill({
    required this.label,
    super.key,
    this.tone = StatusTone.neutral,
    this.icon,
    this.dense = false,
  });

  /// The text label. Always present — colour is never the only signal.
  final String label;

  /// The tone.
  final StatusTone tone;

  /// An optional leading icon.
  final IconData? icon;

  /// Whether to use the compact padding.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);

    final (Color foreground, Color background) = switch (tone) {
      StatusTone.positive => (
          colors.positive,
          colors.positive.withValues(alpha: 0.12)
        ),
      StatusTone.warning => (
          colors.warning,
          colors.warning.withValues(alpha: 0.14)
        ),
      StatusTone.critical => (
          colors.critical,
          colors.critical.withValues(alpha: 0.12)
        ),
      StatusTone.primary => (
          theme.colorScheme.primary,
          theme.colorScheme.primary.withValues(alpha: 0.12)
        ),
      StatusTone.neutral => (
          theme.colorScheme.onSurfaceVariant,
          theme.colorScheme.surfaceContainerHigh
        ),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 14, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTypography.labelMicro.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}
