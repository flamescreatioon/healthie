/// The application theme.
///
/// Material 3, built from the PRD's Clinical Clarity tokens rather than a
/// generated seed, so that surfaces, borders, and semantic colours match the
/// approved designs exactly.
///
/// Dark mode is a first-class variant, not an afterthought: surfaces, borders,
/// grid lines, and the fixed metric accents all have dark counterparts.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// The brand primary — Royal Blue.
const Color kBrandPrimary = Color(0xFF3B60E4);

/// The brand secondary — Deep Cyan (WCAG AA compliant contrast).
const Color kBrandSecondary = Color(0xFF007A9E);

/// The brand tertiary — Warm Amber (WCAG AA compliant contrast).
const Color kBrandTertiary = Color(0xFFB35300);

abstract final class AppTheme {
  /// The light theme.
  static ThemeData get light {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: kBrandPrimary,
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFE7ECFD),
      onPrimaryContainer: Color(0xFF0A2472),
      secondary: kBrandSecondary,
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFE0F7FC),
      onSecondaryContainer: Color(0xFF004B60),
      tertiary: kBrandTertiary,
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFFFFF3E5),
      onTertiaryContainer: Color(0xFF613100),
      error: Color(0xFFDC2626),
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFFFFDAD6),
      onErrorContainer: Color(0xFF93000A),
      surface: Color(0xFFFAF9F9),
      onSurface: Color(0xFF080708),
      surfaceDim: Color(0xFFDED9DA),
      surfaceBright: Color(0xFFFAF9F9),
      surfaceContainerLowest: Color(0xFFFFFFFF),
      surfaceContainerLow: Color(0xFFF4F3F5),
      surfaceContainer: Color(0xFFECEAEF),
      surfaceContainerHigh: Color(0xFFE4E1E8),
      surfaceContainerHighest: Color(0xFFDBD8E0),
      onSurfaceVariant: Color(0xFF55555E),
      outline: Color(0xFF737582),
      outlineVariant: Color(0xFFD0D2DD),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFF323031),
      onInverseSurface: Color(0xFFF5EFF1),
      inversePrimary: Color(0xFFB8C4FF),
    );
    return _build(scheme, const AppColors.light());
  }

  /// The dark theme.
  static ThemeData get dark {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF9DB2FF),
      onPrimary: Color(0xFF0A1B4D),
      primaryContainer: Color(0xFF27418F),
      onPrimaryContainer: Color(0xFFDDE1FF),
      secondary: Color(0xFF5FD0F5),
      onSecondary: Color(0xFF00364A),
      secondaryContainer: Color(0xFF004E66),
      onSecondaryContainer: Color(0xFFBEE9FF),
      tertiary: Color(0xFFFFB865),
      onTertiary: Color(0xFF4A2800),
      tertiaryContainer: Color(0xFF6A3E00),
      onTertiaryContainer: Color(0xFFFFDDBC),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: Color(0xFF121114),
      onSurface: Color(0xFFE5E1E6),
      surfaceDim: Color(0xFF121114),
      surfaceBright: Color(0xFF37343B),
      surfaceContainerLowest: Color(0xFF0D0D0F),
      surfaceContainerLow: Color(0xFF1A1A1E),
      surfaceContainer: Color(0xFF1E1E23),
      surfaceContainerHigh: Color(0xFF29282E),
      surfaceContainerHighest: Color(0xFF34333A),
      onSurfaceVariant: Color(0xFFC9C5D0),
      outline: Color(0xFF938F99),
      outlineVariant: Color(0xFF49454F),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFFE5E1E6),
      onInverseSurface: Color(0xFF323031),
      inversePrimary: Color(0xFF3B60E4),
    );
    return _build(scheme, const AppColors.dark());
  }

  static ThemeData _build(ColorScheme scheme, AppColors appColors) {
    final textTheme = buildTextTheme(scheme);
    final isLight = scheme.brightness == Brightness.light;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      fontFamily: kFontFamily,
      extensions: [appColors],
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface.withValues(alpha: 0.85),
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.headlineSmall.copyWith(
          color: scheme.onSurface,
        ),
        systemOverlayStyle:
            isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.7),
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(kMinTouchTarget),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
          disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
          textStyle: AppTypography.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(kMinTouchTarget),
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: AppTypography.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: AppTypography.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(kMinTouchTarget),
          foregroundColor: scheme.onSurfaceVariant,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        selectedColor: scheme.primary,
        labelStyle: AppTypography.labelMedium,
        secondaryLabelStyle: AppTypography.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        labelStyle: AppTypography.bodyMedium,
        helperStyle: AppTypography.bodySmall,
        errorStyle: AppTypography.bodySmall.copyWith(color: scheme.error),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface.withValues(alpha: 0.92),
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: 0.12),
        elevation: 0,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => AppTypography.labelMicro.copyWith(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w600,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        titleTextStyle: AppTypography.headlineSmall.copyWith(
          color: scheme.onSurface,
        ),
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: AppTypography.labelLarge,
        subtitleTextStyle: AppTypography.bodySmall,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        textStyle: AppTypography.bodySmall.copyWith(
          color: scheme.onInverseSurface,
        ),
      ),
    );
  }
}
