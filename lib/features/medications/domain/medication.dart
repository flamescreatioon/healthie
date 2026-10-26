/// Medication domain models.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'medication.freezed.dart';

/// The status of a scheduled medication dose.
enum MedicationLogStatus {
  taken('taken'),
  skipped('skipped'),
  missed('missed');

  const MedicationLogStatus(this.wireName);

  final String wireName;

  static MedicationLogStatus fromWireName(String wireName) =>
      MedicationLogStatus.values.firstWhere(
        (status) => status.wireName == wireName,
        orElse: () => MedicationLogStatus.missed,
      );
}

/// A user's medication.
@freezed
abstract class Medication with _$Medication {
  const factory Medication({
    required String id,
    required String name,
    required String dosageInstructions,
    required String schedule, // e.g. "08:00, 20:00"
    required DateTime startDate,
    required DateTime? endDate,
    @Default(true) bool active,
  }) = _Medication;

  const Medication._();
}

/// A logged dose of a medication.
@freezed
abstract class MedicationLog with _$MedicationLog {
  const factory MedicationLog({
    required String id,
    required String medicationId,
    required DateTime scheduledAt,
    required MedicationLogStatus status,
    required DateTime recordedAt,
    String? notes,
  }) = _MedicationLog;

  const MedicationLog._();
}
