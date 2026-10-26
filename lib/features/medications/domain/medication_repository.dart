/// Interface for medication data access.
library;

import 'medication.dart';

abstract interface class MedicationRepository {
  Stream<List<Medication>> watchMedications();
  Future<List<Medication>> getMedications();
  Future<void> saveMedication(Medication medication);
  Future<void> deleteMedication(String id);
  Stream<List<MedicationLog>> watchMedicationLogs();
  Future<List<MedicationLog>> getMedicationLogs();
  Future<List<MedicationLog>> getLogsForMedication(String medicationId);
  Future<void> logMedication(MedicationLog log);
}
