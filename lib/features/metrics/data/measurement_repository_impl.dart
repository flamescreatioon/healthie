/// The Drift-backed implementation of [MeasurementRepository].
///
/// Every write commits the measurement and its sync operation in one
/// transaction. That atomicity is the whole point: a crash can never leave a
/// saved reading without a pending upload, and a failed upload never discards
/// a local record.
library;

import '../../../core/database/app_database.dart';
import '../../../core/error/app_failure.dart';
import '../../../core/sync/sync_outbox_dao.dart';
import '../../../core/utils/date_range.dart';
import '../domain/measurement.dart';
import '../domain/measurement_repository.dart';
import '../domain/metric_type.dart';
import 'measurement_dao.dart';

class MeasurementRepositoryImpl implements MeasurementRepository {
  const MeasurementRepositoryImpl(
    this._database,
    this._dao,
    this._outbox,
  );

  final AppDatabase _database;
  final MeasurementDao _dao;
  final SyncOutboxDao _outbox;

  @override
  Stream<List<Measurement>> watchMeasurements({
    required MetricType type,
    required DateRange range,
  }) {
    return _dao
        .watchByType(type.wireName, start: range.start, end: range.end)
        .handleError((Object error, StackTrace stackTrace) {
      throw StorageFailure('Could not read ${type.wireName} measurements.',
          cause: error);
    });
  }

  @override
  Stream<List<Measurement>> watchAllMeasurements({required DateRange range}) {
    return _dao.watchAll(start: range.start, end: range.end).handleError(
      (Object error, StackTrace stackTrace) {
        throw StorageFailure('Could not read measurements.', cause: error);
      },
    );
  }

  @override
  Future<List<Measurement>> measurementsFor(
    MetricType type,
    DateRange range,
  ) async {
    try {
      return await _dao.byType(
        type.wireName,
        start: range.start,
        end: range.end,
      );
    } on Object catch (error) {
      throw StorageFailure('Could not read ${type.wireName} measurements.',
          cause: error);
    }
  }

  @override
  Future<List<Measurement>> allMeasurements(DateRange range) async {
    try {
      return await _dao.all(start: range.start, end: range.end);
    } on Object catch (error) {
      throw StorageFailure('Could not read measurements.', cause: error);
    }
  }

  @override
  Future<Measurement?> latestOf(MetricType type) async {
    try {
      return await _dao.latestOf(type.wireName);
    } on Object catch (error) {
      throw StorageFailure('Could not read the latest reading.', cause: error);
    }
  }

  @override
  Future<Measurement?> findById(String id) async {
    try {
      return await _dao.byId(id);
    } on Object catch (error) {
      throw StorageFailure('Could not read the record.', cause: error);
    }
  }

  @override
  Future<void> save(Measurement measurement) async {
    try {
      await _database.transaction(() async {
        await _dao.upsert(measurement);
        await _outbox.enqueue(
          operation: 'upsert',
          entityType: 'measurements',
          entityId: measurement.id,
          payload: measurement.toJson(),
        );
      });
    } on AppFailure {
      rethrow;
    } on Object catch (error) {
      throw StorageFailure(
        "Couldn't save your entry. Your data is still here — try again.",
        cause: error,
      );
    }
  }

  @override
  Future<void> softDelete(String id, {required DateTime deletedAt}) async {
    try {
      await _database.transaction(() async {
        await _dao.softDelete(id, deletedAt: deletedAt);
        await _outbox.enqueue(
          operation: 'delete',
          entityType: 'measurements',
          entityId: id,
          payload: <String, dynamic>{
            'id': id,
            'deleted_at': deletedAt.toUtc().toIso8601String(),
          },
        );
      });
    } on Object catch (error) {
      throw StorageFailure('Could not delete the record.', cause: error);
    }
  }

  @override
  Future<void> restore(String id, {required DateTime updatedAt}) async {
    try {
      await _database.transaction(() async {
        await _dao.restore(id, updatedAt: updatedAt);
        await _outbox.enqueue(
          operation: 'upsert',
          entityType: 'measurements',
          entityId: id,
          payload: <String, dynamic>{
            'id': id,
            'restored_at': updatedAt.toUtc().toIso8601String(),
          },
        );
      });
    } on Object catch (error) {
      throw StorageFailure('Could not restore the record.', cause: error);
    }
  }
}
