/// Drift access for the measurements table.
///
/// Lives in `data/` and is the only place that knows Drift row shapes exist.
/// Everything it returns is already a domain [Measurement].
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/units/unit.dart';
import '../domain/measurement.dart';
import '../domain/metric_type.dart';
import '../domain/reading_context.dart';

class MeasurementDao {
  const MeasurementDao(this._db);

  final AppDatabase _db;

  Stream<List<Measurement>> watchByType(
    String metricType, {
    required DateTime start,
    required DateTime end,
  }) {
    final query = _db.select(_db.measurements)
      ..where((row) {
        return row.metricType.equals(metricType) &
            row.deletedAt.isNull() &
            row.recordedAt.isBiggerOrEqualValue(start) &
            row.recordedAt.isSmallerThanValue(end);
      })
      ..orderBy([(row) => OrderingTerm.desc(row.recordedAt)]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  Stream<List<Measurement>> watchAll({
    required DateTime start,
    required DateTime end,
  }) {
    final query = _db.select(_db.measurements)
      ..where((row) {
        return row.deletedAt.isNull() &
            row.recordedAt.isBiggerOrEqualValue(start) &
            row.recordedAt.isSmallerThanValue(end);
      })
      ..orderBy([(row) => OrderingTerm.desc(row.recordedAt)]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  Future<List<Measurement>> byType(
    String metricType, {
    required DateTime start,
    required DateTime end,
  }) async {
    final query = _db.select(_db.measurements)
      ..where((row) {
        return row.metricType.equals(metricType) &
            row.deletedAt.isNull() &
            row.recordedAt.isBiggerOrEqualValue(start) &
            row.recordedAt.isSmallerThanValue(end);
      })
      ..orderBy([(row) => OrderingTerm.desc(row.recordedAt)]);
    return (await query.get()).map(_toDomain).toList();
  }

  Future<List<Measurement>> all({
    required DateTime start,
    required DateTime end,
  }) async {
    final query = _db.select(_db.measurements)
      ..where((row) {
        return row.deletedAt.isNull() &
            row.recordedAt.isBiggerOrEqualValue(start) &
            row.recordedAt.isSmallerThanValue(end);
      })
      ..orderBy([(row) => OrderingTerm.desc(row.recordedAt)]);
    return (await query.get()).map(_toDomain).toList();
  }

  Future<Measurement?> latestOf(String metricType) async {
    final query = _db.select(_db.measurements)
      ..where((row) => row.metricType.equals(metricType) & row.deletedAt.isNull())
      ..orderBy([(row) => OrderingTerm.desc(row.recordedAt)])
      ..limit(1);
    final rows = await query.get();
    return rows.isEmpty ? null : _toDomain(rows.first);
  }

  Future<Measurement?> byId(String id) async {
    final query = _db.select(_db.measurements)
      ..where((row) => row.id.equals(id));
    final rows = await query.get();
    return rows.isEmpty ? null : _toDomain(rows.first);
  }

  /// Inserts or replaces a row.
  Future<void> upsert(Measurement measurement) async {
    await _db.into(_db.measurements).insertOnConflictUpdate(
          MeasurementsCompanion.insert(
            id: measurement.id,
            metricType: measurement.metricType.wireName,
            value: measurement.value,
            unit: measurement.unit.symbol,
            secondaryValue: Value(measurement.secondaryValue),
            secondaryUnit: Value(measurement.secondaryUnit?.symbol),
            tertiaryValue: Value(measurement.tertiaryValue),
            tertiaryUnit: Value(measurement.tertiaryUnit?.symbol),
            recordedAt: measurement.recordedAt,
            localDay: measurement.localDay,
            createdAt: measurement.createdAt,
            updatedAt: measurement.updatedAt,
            source: measurement.source.wireName,
            isSynced: Value(measurement.isSynced),
            deletedAt: Value(measurement.deletedAt),
            contextJson: Value(_encodeContext(measurement.context)),
          ),
        );
  }

  /// Soft-deletes a row. Rows are never removed from the table.
  Future<void> softDelete(String id, {required DateTime deletedAt}) async {
    await (_db.update(_db.measurements)..where((row) => row.id.equals(id))).write(
      MeasurementsCompanion(
        deletedAt: Value(deletedAt),
        updatedAt: Value(deletedAt),
      ),
    );
  }

  /// Clears the tombstone on a soft-deleted row.
  Future<void> restore(String id, {required DateTime updatedAt}) async {
    await (_db.update(_db.measurements)..where((row) => row.id.equals(id))).write(
      MeasurementsCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  static String _encodeContext(MeasurementContext context) =>
      jsonEncode(context.toJson());

  static Measurement _toDomain(MeasurementRow row) {
    final rawContext = row.contextJson;
    return Measurement(
      id: row.id,
      metricType: MetricType.fromWireName(row.metricType)!,
      value: row.value,
      unit: _unitFromSymbol(row.unit),
      secondaryValue: row.secondaryValue,
      secondaryUnit: row.secondaryUnit == null
          ? null
          : _unitFromSymbol(row.secondaryUnit!),
      tertiaryValue: row.tertiaryValue,
      tertiaryUnit: row.tertiaryUnit == null
          ? null
          : _unitFromSymbol(row.tertiaryUnit!),
      recordedAt: row.recordedAt.toUtc(),
      localDay: row.localDay,
      createdAt: row.createdAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
      source: MeasurementSource.fromWireName(row.source),
      isSynced: row.isSynced,
      deletedAt: row.deletedAt?.toUtc(),
      context: rawContext == null || rawContext.isEmpty
          ? MeasurementContext.empty
          : MeasurementContext.fromJson(
              Map<String, dynamic>.from(jsonDecode(rawContext) as Map),
            ),
    );
  }

  static Unit _unitFromSymbol(String symbol) => Unit.values.firstWhere(
        (unit) => unit.symbol == symbol,
        orElse: () => Unit.percent,
      );
}
