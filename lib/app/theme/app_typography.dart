/// The type scale.
///
/// One family — Inter — with a few weights. Every numeric style uses
/// OpenType tabular figures so a column of changing values does not jitter
/// horizontally as digits change.
library;

import 'package:flutter/material.dart';

/// The font family bundled with the app.
const String kFontFamily = 'Inter';

/// Tabular figures: digits occupy a fixed width.
const List<FontFeature> kTabularFigures = [FontFeature.tabularFigures()];

/// Named text styles, so a screen never guesses a size.
abstract final class AppTypography {
  /// A headline statistic: 32/36, weight 700.
  static const TextStyle displayNumeric = TextStyle(
    fontFamily: kFontFamily,
    fontSize: 32,
    height: 36 / 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.02,
    fontFeatures: kTabularFigures,
  );

  /// The largest statistic, for a single hero number: 40/44, weight 700.
  static const TextStyle displayNumericLarge = TextStyle(
    fontFamily: kFontFamily,
    fontSize: 40,
    height: 44 / 40,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.03,
    fontFeatures: kTabularFigures,
  );

  /// Screen title: 28/34, weight 700.
  static const TextStyle headlineLarge = TextStyle(
    fontFamily: kFontFamily,
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.02,
  );

  /// Section title: 22/28, weight 600.
  static const TextStyle headlineMedium = TextStyle(
    fontFamily: kFontFamily,
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.01,
  );

  /// Card title: 18/24, weight 600.
  static const TextStyle headlineSmall = TextStyle(
    fontFamily: kFontFamily,
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w600,
  );

  /// Primary body text: 16/24, weight 400.
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: kFontFamily,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
  );

  /// Body text: 14/20, weight 400.
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: kFontFamily,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
  );

  /// Secondary text: 12/16, weight 400.
  static const TextStyle bodySmall = TextStyle(
    fontFamily: kFontFamily,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
  );

  /// Emphasised label: 14/20, weight 600.
  static const TextStyle labelLarge = TextStyle(
    fontFamily: kFontFamily,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.01,
  );

  /// Small label: 12/16, weight 600.
  static const TextStyle labelMedium = TextStyle(
    fontFamily: kFontFamily,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.02,
  );

  /// Micro label, for units and categories: 10/12, weight 700, wide tracking.
  static const TextStyle labelMicro = TextStyle(
    fontFamily: kFontFamily,
    fontSize: 10,
    height: 12 / 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.05,
  );
}

/// Builds the Material [TextTheme] from the named styles.
TextTheme buildTextTheme(ColorScheme colors) {
  final base = Typography.material2021().black.apply(
        fontFamily: kFontFamily,
        bodyColor: colors.onSurface,
        displayColor: colors.onSurface,
      );

  TextStyle withColor(TextStyle style, Color color) =>
      style.copyWith(color: color);

  return base.copyWith(
    displayLarge: withColor(AppTypography.displayNumericLarge, colors.onSurface),
    displayMedium: withColor(AppTypography.displayNumeric, colors.onSurface),
    displaySmall: withColor(AppTypography.displayNumeric, colors.onSurface),
    headlineLarge: withColor(AppTypography.headlineLarge, colors.onSurface),
    headlineMedium: withColor(AppTypography.headlineMedium, colors.onSurface),
    headlineSmall: withColor(AppTypography.headlineSmall, colors.onSurface),
    titleLarge: withColor(AppTypography.headlineSmall, colors.onSurface),
    titleMedium: withColor(AppTypography.labelLarge, colors.onSurface),
    titleSmall: withColor(AppTypography.labelMedium, colors.onSurface),
    bodyLarge: withColor(AppTypography.bodyLarge, colors.onSurface),
    bodyMedium: withColor(AppTypography.bodyMedium, colors.onSurface),
    bodySmall: withColor(AppTypography.bodySmall, colors.onSurfaceVariant),
    labelLarge: withColor(AppTypography.labelLarge, colors.onSurface),
    labelMedium: withColor(AppTypography.labelMedium, colors.onSurfaceVariant),
    labelSmall: withColor(AppTypography.labelMicro, colors.onSurfaceVariant),
  );
}
