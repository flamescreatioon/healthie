/// Drift access for medications and medication logs.
library;

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
// ignore: unused_import
import '../domain/medication.dart';

class MedicationDao {
  const MedicationDao(this._db);

  final AppDatabase _db;

  Stream<List<MedicationRow>> watchAllMedications() {
    return _db.select(_db.medications).watch();
  }

  Future<List<MedicationRow>> getAllMedications() async {
    return _db.select(_db.medications).get();
  }

  Future<void> upsertMedication(MedicationRow medication) async {
    await _db.into(_db.medications).insertOnConflictUpdate(medication);
  }

  Future<void> deleteMedication(String id) async {
    await (_db.delete(_db.medications)..where((t) => t.id.equals(id))).go();
  }

  Stream<List<MedicationLogRow>> watchMedicationLogs() {
    return _db.select(_db.medicationLogs).watch();
  }

  Future<List<MedicationLogRow>> getAllMedicationLogs() async {
    return _db.select(_db.medicationLogs).get();
  }

  Future<void> upsertMedicationLog(MedicationLogRow log) async {
    await _db.into(_db.medicationLogs).insertOnConflictUpdate(log);
  }

  Future<List<MedicationLogRow>> getLogsForMedication(
    String medicationId,
  ) async {
    return (_db.select(_db.medicationLogs)
          ..where((t) => t.medicationId.equals(medicationId))
          ..orderBy([(t) => OrderingTerm.desc(t.scheduledAt)]))
        .get();
  }
}
