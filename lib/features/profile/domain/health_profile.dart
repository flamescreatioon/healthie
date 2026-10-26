/// The user's health profile and their targets.
///
/// Healthie does not ask for information it does not need. Height is optional
/// and only used for BMI; sex and date of birth are optional and only used
/// where a calculation genuinely requires them.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/units/unit.dart';

part 'health_profile.freezed.dart';

/// What the user wants their weight to do.
enum WeightGoalKind {
  /// No weight goal at all.
  none('none', 'No goal'),

  /// Keep the weight steady.
  maintain('maintain', 'Maintain'),

  /// Move towards a lower weight.
  lose('lose', 'Lose'),

  /// Move towards a higher weight.
  gain('gain', 'Gain');

  const WeightGoalKind(this.wireName, this.label);

  final String wireName;
  final String label;

  static WeightGoalKind fromWireName(String wireName) =>
      WeightGoalKind.values.firstWhere(
        (kind) => kind.wireName == wireName,
        orElse: () => WeightGoalKind.none,
      );
}

@freezed
abstract class HealthProfile with _$HealthProfile {
  const factory HealthProfile({
    required String id,
    String? displayName,
    DateTime? dateOfBirth,
    String? sex,
    double? heightCm,
    @Default(Unit.kilogram) Unit preferredMassUnit,
    @Default(Unit.centimetre) Unit preferredLengthUnit,
    @Default(Unit.celsius) Unit preferredTemperatureUnit,
    String? timeZone,
    @Default(WeightGoalKind.none) WeightGoalKind weightGoalKind,
    int? targetSystolic,
    int? targetDiastolic,
    DateTime? targetWeightKg,
  }) = _HealthProfile;
}

/// A user-defined target for a metric.
@freezed
abstract class HealthGoal with _$HealthGoal {
  const factory HealthGoal({
    required String id,
    required String metricType,
    required double targetValue,
    required Unit unit,
    DateTime? targetDate,
    @Default(true) bool active,
  }) = _HealthGoal;
}
