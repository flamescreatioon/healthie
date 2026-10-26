/// Drift-backed implementation of [MedicationRepository].
library;

import '../../../core/database/app_database.dart';
import '../domain/medication.dart';
import '../domain/medication_repository.dart';
import 'medication_dao.dart';

class MedicationRepositoryImpl implements MedicationRepository {
  const MedicationRepositoryImpl(this._dao);

  final MedicationDao _dao;

  @override
  Stream<List<Medication>> watchMedications() {
    return _dao.watchAllMedications().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Future<List<Medication>> getMedications() async {
    final rows = await _dao.getAllMedications();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<void> saveMedication(Medication medication) async {
    await _dao.upsertMedication(
      MedicationRow(
        id: medication.id,
        name: medication.name,
        dosageInstructions: medication.dosageInstructions,
        schedule: medication.schedule,
        startDate: medication.startDate,
        endDate: medication.endDate,
        active: medication.active,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  @override
  Future<void> deleteMedication(String id) async {
    await _dao.deleteMedication(id);
  }

  @override
  Stream<List<MedicationLog>> watchMedicationLogs() {
    return _dao.watchMedicationLogs().map((rows) => rows.map(_logToDomain).toList());
  }

  @override
  Future<List<MedicationLog>> getMedicationLogs() async {
    final rows = await _dao.getAllMedicationLogs();
    return rows.map(_logToDomain).toList();
  }

  @override
  Future<List<MedicationLog>> getLogsForMedication(String medicationId) async {
    final rows = await _dao.getLogsForMedication(medicationId);
    return rows.map(_logToDomain).toList();
  }

  @override
  Future<void> logMedication(MedicationLog log) async {
    await _dao.upsertMedicationLog(
      MedicationLogRow(
        id: log.id,
        medicationId: log.medicationId,
        scheduledAt: log.scheduledAt,
        status: log.status.wireName,
        recordedAt: log.recordedAt,
        notes: log.notes,
      ),
    );
  }

  static Medication _toDomain(MedicationRow row) => Medication(
        id: row.id,
        name: row.name,
        dosageInstructions: row.dosageInstructions,
        schedule: row.schedule,
        startDate: row.startDate,
        endDate: row.endDate,
        active: row.active,
      );

  static MedicationLog _logToDomain(MedicationLogRow row) => MedicationLog(
        id: row.id,
        medicationId: row.medicationId,
        scheduledAt: row.scheduledAt,
        status: MedicationLogStatus.fromWireName(row.status),
        recordedAt: row.recordedAt,
        notes: row.notes,
      );
}
