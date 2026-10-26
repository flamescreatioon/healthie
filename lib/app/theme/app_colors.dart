/// The "Clinical Clarity" palette.
///
/// One colour system, extended explicitly for the semantic colours the app
/// needs. Metric accents are **fixed**: blood pressure is the same blue on
/// every screen, so the user learns the mapping once.
///
/// Semantic colours are scarce on purpose. `positive`, `warning`, and
/// `critical` are reserved for things that genuinely have a direction and a
/// judgement — a value outside a reference band, a safety alert. They are
/// never used to decorate a trend line, because a trend is not inherently
/// good or bad.
library;

import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.positive,
    required this.warning,
    required this.critical,
    required this.neutral,
    required this.metricBloodPressure,
    required this.metricWeight,
    required this.metricHeartRate,
    required this.metricOxygen,
    required this.metricTemperature,
    required this.metricGlucose,
  });

  /// Light-mode palette, derived from the PRD's Clinical Clarity tokens.
  const AppColors.light()
      : positive = const Color(0xFF16A34A),
        warning = const Color(0xFFB35300),
        critical = const Color(0xFFDC2626),
        neutral = const Color(0xFF5C6370),
        metricBloodPressure = const Color(0xFF3B60E4),
        metricWeight = const Color(0xFF007A9E),
        metricHeartRate = const Color(0xFFD6336C),
        metricOxygen = const Color(0xFF7C5CD6),
        metricTemperature = const Color(0xFFB35300),
        metricGlucose = const Color(0xFF0F9D8C);

  /// Dark-mode palette.
  ///
  /// The fixed metric accents are lightened so they stay legible against dark
  /// surfaces without turning neon.
  const AppColors.dark()
      : positive = const Color(0xFF4ADE80),
        warning = const Color(0xFFFBBF24),
        critical = const Color(0xFFF87171),
        neutral = const Color(0xFF9AA0A6),
        metricBloodPressure = const Color(0xFF8FA9FF),
        metricWeight = const Color(0xFF5FD0F5),
        metricHeartRate = const Color(0xFFF783A9),
        metricOxygen = const Color(0xFFB9A4F5),
        metricTemperature = const Color(0xFFFFB865),
        metricGlucose = const Color(0xFF4FD1C5);

  /// A value inside its reference band.
  final Color positive;

  /// A value that needs attention but is not dangerous.
  final Color warning;

  /// A value that needs prompt action.
  final Color critical;

  /// Secondary metadata: timestamps, units, inactive indicators.
  final Color neutral;

  /// The fixed accent for blood pressure.
  final Color metricBloodPressure;

  /// The fixed accent for body weight.
  final Color metricWeight;

  /// The fixed accent for heart rate.
  final Color metricHeartRate;

  /// The fixed accent for blood oxygen saturation.
  final Color metricOxygen;

  /// The fixed accent for body temperature.
  final Color metricTemperature;

  /// The fixed accent for blood glucose.
  final Color metricGlucose;

  /// Reads the extended palette from [context].
  ///
  /// Falls back to the light palette when the extension is not installed, so
  /// a widget can be rendered in isolation — in a test, or in a preview — and
  /// still look right instead of throwing.
  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ?? const AppColors.light();

  @override
  AppColors copyWith({
    Color? positive,
    Color? warning,
    Color? critical,
    Color? neutral,
    Color? metricBloodPressure,
    Color? metricWeight,
    Color? metricHeartRate,
    Color? metricOxygen,
    Color? metricTemperature,
    Color? metricGlucose,
  }) {
    return AppColors(
      positive: positive ?? this.positive,
      warning: warning ?? this.warning,
      critical: critical ?? this.critical,
      neutral: neutral ?? this.neutral,
      metricBloodPressure: metricBloodPressure ?? this.metricBloodPressure,
      metricWeight: metricWeight ?? this.metricWeight,
      metricHeartRate: metricHeartRate ?? this.metricHeartRate,
      metricOxygen: metricOxygen ?? this.metricOxygen,
      metricTemperature: metricTemperature ?? this.metricTemperature,
      metricGlucose: metricGlucose ?? this.metricGlucose,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      positive: Color.lerp(positive, other.positive, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      critical: Color.lerp(critical, other.critical, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
      metricBloodPressure:
          Color.lerp(metricBloodPressure, other.metricBloodPressure, t)!,
      metricWeight: Color.lerp(metricWeight, other.metricWeight, t)!,
      metricHeartRate: Color.lerp(metricHeartRate, other.metricHeartRate, t)!,
      metricOxygen: Color.lerp(metricOxygen, other.metricOxygen, t)!,
      metricTemperature: Color.lerp(metricTemperature, other.metricTemperature, t)!,
      metricGlucose: Color.lerp(metricGlucose, other.metricGlucose, t)!,
    );
  }
}

/// Convenience access to the extended palette.
extension AppColorsContext on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}
