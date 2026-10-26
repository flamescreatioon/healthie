/// The context a measurement was taken in.
///
/// Context is what makes a number interpretable. "118/76" alone is a pair of
/// numbers; "118/76, sitting, left arm, after exercise" is a data point a
/// clinician can reason about. Every contextual field is optional â€” the user
/// should never be forced to answer a question to log a value.
library;

import 'package:flutter/foundation.dart';

/// How the body was positioned during a measurement.
enum BodyPosture {
  sitting('sitting', 'Sitting'),
  lyingDown('lying_down', 'Lying down'),
  standing('standing', 'Standing');

  const BodyPosture(this.wireName, this.label);

  final String wireName;
  final String label;

  static BodyPosture? fromWireName(String wireName) {
    for (final posture in BodyPosture.values) {
      if (posture.wireName == wireName) return posture;
    }
    return null;
  }
}

/// Which arm a measurement was taken on.
enum MeasurementArm {
  left('left', 'Left Arm'),
  right('right', 'Right Arm');

  const MeasurementArm(this.wireName, this.label);

  final String wireName;
  final String label;

  static MeasurementArm? fromWireName(String wireName) {
    for (final arm in MeasurementArm.values) {
      if (arm.wireName == wireName) return arm;
    }
    return null;
  }
}

/// The circumstances surrounding a measurement.
///
/// More than one may apply: a reading taken "post-exercise" and "stressed" is
/// a perfectly ordinary thing to record.
enum ReadingCircumstance {
  resting('resting', 'Resting'),
  postExercise('post_exercise', 'Post-exercise'),
  beforeMedication('before_medication', 'Before medication'),
  afterMedication('after_medication', 'After medication'),
  stressed('stressed', 'Stressed'),
  fasting('fasting', 'Fasting');

  const ReadingCircumstance(this.wireName, this.label);

  final String wireName;
  final String label;

  static ReadingCircumstance? fromWireName(String wireName) {
    for (final circumstance in ReadingCircumstance.values) {
      if (circumstance.wireName == wireName) return circumstance;
    }
    return null;
  }
}

/// When during the day a weight was taken.
enum WeightTimeOfDay {
  morningFasting('morning_fasting', 'Morning fasting'),
  postMeal('post_meal', 'Post-meal'),
  evening('evening', 'Evening');

  const WeightTimeOfDay(this.wireName, this.label);

  final String wireName;
  final String label;

  static WeightTimeOfDay? fromWireName(String wireName) {
    for (final slot in WeightTimeOfDay.values) {
      if (slot.wireName == wireName) return slot;
    }
    return null;
  }
}

/// Everything known about *how* and *when* a measurement was taken, beyond the
/// number itself.
@immutable
class MeasurementContext {
  const MeasurementContext({
    this.posture,
    this.arm,
    this.circumstances = const <ReadingCircumstance>{},
    this.weightTimeOfDay,
    this.notes,
    this.device,
  });

  /// Decodes a context from its wire representation.
  factory MeasurementContext.fromJson(Map<String, dynamic> json) {
    final rawCircumstances = json['circumstances'];
    return MeasurementContext(
      posture: json['posture'] is String
          ? BodyPosture.fromWireName(json['posture']! as String)
          : null,
      arm: json['arm'] is String
          ? MeasurementArm.fromWireName(json['arm']! as String)
          : null,
      circumstances: rawCircumstances is List
          ? rawCircumstances
              .whereType<String>()
              .map(ReadingCircumstance.fromWireName)
              .nonNulls
              .toSet()
          : const <ReadingCircumstance>{},
      weightTimeOfDay: json['weight_time_of_day'] is String
          ? WeightTimeOfDay.fromWireName(json['weight_time_of_day']! as String)
          : null,
      notes: json['notes'] as String?,
      device: json['device'] as String?,
    );
  }

  /// No context at all.
  static const MeasurementContext empty = MeasurementContext();

  /// Body position, when relevant.
  final BodyPosture? posture;

  /// Arm used, when relevant.
  final MeasurementArm? arm;

  /// The circumstances that applied. May be empty, never contains duplicates.
  final Set<ReadingCircumstance> circumstances;

  /// The time-of-day slot for a weight reading.
  final WeightTimeOfDay? weightTimeOfDay;

  /// Free-form notes typed by the user.
  final String? notes;

  /// The device the reading came from, e.g. "OMRON connect".
  final String? device;

  /// Whether any context at all was recorded.
  bool get isEmpty =>
      posture == null &&
      arm == null &&
      circumstances.isEmpty &&
      weightTimeOfDay == null &&
      (notes == null || notes!.isEmpty) &&
      device == null;

  MeasurementContext copyWith({
    BodyPosture? posture,
    MeasurementArm? arm,
    Set<ReadingCircumstance>? circumstances,
    WeightTimeOfDay? weightTimeOfDay,
    String? notes,
    String? device,
    bool clearNotes = false,
    bool clearDevice = false,
    bool clearPosture = false,
    bool clearArm = false,
    bool clearWeightTimeOfDay = false,
  }) {
    return MeasurementContext(
      posture: clearPosture ? null : (posture ?? this.posture),
      arm: clearArm ? null : (arm ?? this.arm),
      circumstances: circumstances ?? this.circumstances,
      weightTimeOfDay: clearWeightTimeOfDay
          ? null
          : (weightTimeOfDay ?? this.weightTimeOfDay),
      notes: clearNotes ? null : (notes ?? this.notes),
      device: clearDevice ? null : (device ?? this.device),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (posture != null) 'posture': posture!.wireName,
        if (arm != null) 'arm': arm!.wireName,
        if (circumstances.isNotEmpty)
          'circumstances':
              circumstances.map((c) => c.wireName).toList()..sort(),
        if (weightTimeOfDay != null) 'weight_time_of_day': weightTimeOfDay!.wireName,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        if (device != null && device!.isNotEmpty) 'device': device,
      };

  @override
  bool operator ==(Object other) =>
      other is MeasurementContext &&
      other.posture == posture &&
      other.arm == arm &&
      setEquals(other.circumstances, circumstances) &&
      other.weightTimeOfDay == weightTimeOfDay &&
      other.notes == notes &&
      other.device == device;

  @override
  int get hashCode => Object.hash(
        posture,
        arm,
        Object.hashAllUnordered(circumstances),
        weightTimeOfDay,
        notes,
        device,
      );

  @override
  String toString() =>
      'MeasurementContext(posture: $posture, arm: $arm, '
      'circumstances: $circumstances, weightTimeOfDay: $weightTimeOfDay, '
      'notes: $notes, device: $device)';
}
