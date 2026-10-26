/// The core domain model: a single recorded clinical value.
///
/// A measurement carries its unit, its three timestamps, its provenance, and
/// the context it was taken in. Nothing here depends on how the value was
/// stored or where it will be synced to.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/units/unit.dart';
import 'metric_type.dart';
import 'reading_context.dart';

part 'measurement.freezed.dart';

/// Where a measurement came from.
///
/// Independent of sync state: a Health Connect import can be unsynced, and a
/// manual entry can be synced. Merging the two into one "status" field breaks
/// the sync queue.
enum MeasurementSource {
  manual('manual', 'Manual'),
  healthConnect('health_connect', 'Health Connect'),
  imported('imported', 'Imported'),
  derived('derived', 'Derived');

  const MeasurementSource(this.wireName, this.label);

  final String wireName;
  final String label;

  static MeasurementSource fromWireName(String wireName) =>
      MeasurementSource.values.firstWhere(
        (source) => source.wireName == wireName,
        orElse: () => MeasurementSource.manual,
      );
}

@freezed
abstract class Measurement with _$Measurement {
  const factory Measurement({
    /// Device-generated stable identifier. The server never assigns it.
    required String id,

    /// Which metric this row records.
    required MetricType metricType,

    /// The primary value, in [unit].
    required double value,

    /// The unit of [value]. Always the canonical unit for storage.
    required Unit unit,

    /// The optional second component: diastolic pressure, or body-fat percent.
    double? secondaryValue,

    /// The unit of [secondaryValue].
    Unit? secondaryUnit,

    /// The optional third component: pulse, or waist circumference.
    double? tertiaryValue,

    /// The unit of [tertiaryValue].
    Unit? tertiaryUnit,

    /// When the measurement happened, in UTC.
    required DateTime recordedAt,

    /// The local calendar day containing [recordedAt]. Stored, not computed, so
    /// that day grouping survives timezone changes and DST.
    required DateTime localDay,

    /// When the row was written to this device, in UTC.
    required DateTime createdAt,

    /// When the row was last modified, in UTC.
    required DateTime updatedAt,

    /// Where the measurement came from.
    @Default(MeasurementSource.manual) MeasurementSource source,

    /// Whether the record has reached the server.
    @Default(false) bool isSynced,

    /// Set when the user deletes the record. Soft-deleted rows are hidden from
    /// the UI but retained so the deletion can sync and be undone.
    DateTime? deletedAt,

    /// The circumstances surrounding the measurement.
    @Default(MeasurementContext.empty) MeasurementContext context,
  }) = _Measurement;

  const Measurement._();

  /// Whether the record has been deleted.
  bool get isDeleted => deletedAt != null;

  /// The specification for this measurement's metric.
  MetricSpec get spec => MetricCatalog.specFor(metricType);

  /// The diastolic pressure, for a blood-pressure measurement.
  double? get diastolic => metricType == MetricType.bloodPressure
      ? secondaryValue
      : null;

  /// The pulse, for a blood-pressure measurement.
  double? get pulse => metricType == MetricType.bloodPressure
      ? tertiaryValue
      : null;

  /// The body-fat percentage, for a weight measurement.
  double? get bodyFatPercent =>
      metricType == MetricType.weight ? secondaryValue : null;

  /// The waist circumference, for a weight measurement.
  double? get waistCircumference =>
      metricType == MetricType.weight ? tertiaryValue : null;
}

/// JSON representation of a [Measurement], using stable wire names.
extension MeasurementJson on Measurement {
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'metric_type': metricType.wireName,
        'value': value,
        'unit': unit.symbol,
        if (secondaryValue != null) 'secondary_value': secondaryValue,
        if (secondaryUnit != null) 'secondary_unit': secondaryUnit!.symbol,
        if (tertiaryValue != null) 'tertiary_value': tertiaryValue,
        if (tertiaryUnit != null) 'tertiary_unit': tertiaryUnit!.symbol,
        'recorded_at': recordedAt.toUtc().toIso8601String(),
        'local_day': localDay.toIso8601String(),
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'source': source.wireName,
        'is_synced': isSynced,
        if (deletedAt != null)
          'deleted_at': deletedAt!.toUtc().toIso8601String(),
        'context': context.toJson(),
      };
}

/// Decodes a [Measurement] from its wire representation.
Measurement measurementFromJson(Map<String, dynamic> json) {
  final rawContext = json['context'];
  return Measurement(
    id: json['id']! as String,
    metricType: MetricType.fromWireName(json['metric_type']! as String)!,
    value: (json['value']! as num).toDouble(),
    unit: _unitFromSymbol(json['unit']! as String),
    secondaryValue: (json['secondary_value'] as num?)?.toDouble(),
    secondaryUnit: json['secondary_unit'] is String
        ? _unitFromSymbol(json['secondary_unit']! as String)
        : null,
    tertiaryValue: (json['tertiary_value'] as num?)?.toDouble(),
    tertiaryUnit: json['tertiary_unit'] is String
        ? _unitFromSymbol(json['tertiary_unit']! as String)
        : null,
    recordedAt: DateTime.parse(json['recorded_at']! as String).toUtc(),
    localDay: DateTime.parse(json['local_day']! as String),
    createdAt: DateTime.parse(json['created_at']! as String).toUtc(),
    updatedAt: DateTime.parse(json['updated_at']! as String).toUtc(),
    source: MeasurementSource.fromWireName(json['source']! as String),
    isSynced: json['is_synced'] as bool? ?? false,
    deletedAt: json['deleted_at'] is String
        ? DateTime.parse(json['deleted_at']! as String).toUtc()
        : null,
    context: rawContext is Map
        ? MeasurementContext.fromJson(Map<String, dynamic>.from(rawContext))
        : MeasurementContext.empty,
  );
}

Unit _unitFromSymbol(String symbol) => Unit.values.firstWhere(
      (unit) => unit.symbol == symbol,
      orElse: () => Unit.percent,
    );
