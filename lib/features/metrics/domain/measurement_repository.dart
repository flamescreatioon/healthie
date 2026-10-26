/// The interface the presentation layer uses to reach stored measurements.
///
/// The interface is written in domain terms. It knows nothing about Drift or
/// Supabase, which is what lets a Health Connect import and a manual entry be
/// indistinguishable downstream, and what makes the whole feature testable
/// without a device.
library;

import '../../../../core/utils/date_range.dart';
import 'measurement.dart';
import 'metric_type.dart';

abstract interface class MeasurementRepository {
  /// Emits every measurement of [type] recorded inside [range], newest first.
  ///
  /// Soft-deleted records are excluded.
  Stream<List<Measurement>> watchMeasurements({
    required MetricType type,
    required DateRange range,
  });

  /// Emits every measurement of any type recorded inside [range], newest
  /// first.
  Stream<List<Measurement>> watchAllMeasurements({required DateRange range});

  /// The measurements of [type] inside [range], newest first.
  Future<List<Measurement>> measurementsFor(
    MetricType type,
    DateRange range,
  );

  /// Every measurement inside [range], newest first.
  Future<List<Measurement>> allMeasurements(DateRange range);

  /// The most recent measurement of [type], or null when there is none.
  Future<Measurement?> latestOf(MetricType type);

  /// The measurement with [id], including soft-deleted ones.
  Future<Measurement?> findById(String id);

  /// Inserts or updates [measurement].
  ///
  /// The write and its sync enqueue happen in one transaction, so a crash can
  /// never leave a saved measurement without a pending upload.
  Future<void> save(Measurement measurement);

  /// Soft-deletes the measurement with [id].
  Future<void> softDelete(String id, {required DateTime deletedAt});

  /// Restores a soft-deleted measurement.
  Future<void> restore(String id, {required DateTime updatedAt});
}
