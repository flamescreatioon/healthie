/// Riverpod providers for the metrics feature.
///
/// The repository itself is wired in the composition root
/// (`lib/app/providers.dart`); this file exposes the queries the UI uses.
/// A test overrides either with a fake.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/utils/date_range.dart';
import '../../domain/measurement.dart';
import '../../domain/metric_type.dart';

/// A metric type and a period, as a single value-typed provider argument.
@immutable
class MetricRangeQuery {
  const MetricRangeQuery({required this.type, required this.range});

  final MetricType type;
  final DateRange range;

  @override
  bool operator ==(Object other) =>
      other is MetricRangeQuery &&
      other.type == type &&
      other.range == range;

  @override
  int get hashCode => Object.hash(type, range);
}

/// Every measurement of any type inside a period, newest first.
final allMeasurementsProvider =
    StreamProvider.family<List<Measurement>, DateRange>(
  (ref, range) =>
      ref.watch(measurementRepositoryProvider).watchAllMeasurements(range: range),
);

/// Every measurement of one metric type inside a period, newest first.
final measurementsByTypeProvider =
    StreamProvider.family<List<Measurement>, MetricRangeQuery>(
  (ref, query) => ref
      .watch(measurementRepositoryProvider)
      .watchMeasurements(type: query.type, range: query.range),
);
