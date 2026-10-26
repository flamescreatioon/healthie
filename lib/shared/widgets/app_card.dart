/// The standard surface container.
///
/// One card style for the whole app: a flat surface with a hairline border
/// and no drop shadow. Depth comes from the surface colour and the border,
/// not from heavy shadows, which read as dated.
library;

import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.borderRadius = AppRadius.card,
    this.onTap,
    this.color,
    this.borderColor,
    this.elevated = false,
  });

  /// The card's content.
  final Widget child;

  /// The internal padding.
  final EdgeInsetsGeometry padding;

  /// The corner radius.
  final double borderRadius;

  /// An optional tap handler. When present the card becomes a button.
  final VoidCallback? onTap;

  /// Overrides the surface colour.
  final Color? color;

  /// Overrides the border colour.
  final Color? borderColor;

  /// Whether the card uses the hero radius.
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = elevated ? AppRadius.hero : borderRadius;
    final borderSide = BorderSide(
      color: borderColor ??
          theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
    );

    final content = Padding(padding: padding, child: child);

    if (onTap == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: color ?? theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(radius),
          border: Border.fromBorderSide(borderSide),
        ),
        child: content,
      );
    }

    return Material(
      color: color ?? theme.colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: borderSide,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: content,
      ),
    );
  }
}
