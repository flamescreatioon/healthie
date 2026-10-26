/// Applies pulled `measurements` rows to the local database.
///
/// Conflict and rejected rows are how the server wins: the local copy is
/// overwritten (or the deletion re-applied) and the pull already advanced the
/// cursor in the same transaction, so convergence is automatic.
library;

import '../../features/metrics/data/measurement_dao.dart';
import '../../features/metrics/domain/measurement.dart';
import 'sync_models.dart';

class MeasurementSyncAdapter {
  const MeasurementSyncAdapter(this._dao);

  final MeasurementDao _dao;

  /// Applies one changelog row for the `measurements` entity type.
  Future<void> apply(RemoteChange change) async {
    if (change.entityType != 'measurements') return;

    if (change.operation == 'delete') {
      await _dao.softDelete(change.entityId, deletedAt: DateTime.now().toUtc());
      return;
    }

    final measurement = _measurementFromServer(change.payload);
    if (measurement != null) {
      await _dao.upsert(measurement);
    }
  }

  /// Decodes a server row into the domain model, or null when the payload
  /// carries an unknown metric type instead of failing the whole pull.
  Measurement? _measurementFromServer(Map<String, dynamic> payload) {
    try {
      return measurementFromJson(payload);
    } on Object {
      return null;
    }
  }
}
