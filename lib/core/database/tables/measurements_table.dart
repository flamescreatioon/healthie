/// Every scalar health value Healthie stores.
///
/// One table with a metric discriminator rather than one table per metric: it
/// keeps queries uniform, makes "everything recorded on this day" a single
/// scan, and lets the sync layer treat every metric identically.
///
/// A blood-pressure reading occupies one row (`value` = systolic,
/// `secondary_value` = diastolic, `tertiary_value` = pulse). A weight reading
/// occupies one row (`value` = kg, `secondary_value` = body-fat percent,
/// `tertiary_value` = waist circumference).
///
/// Timestamps use drift's built-in `dateTime()` columns, which store epoch
/// seconds. The instant is preserved regardless of the `isUtc` flag; the
/// repository normalises to UTC when mapping rows into the domain model.
library;

import 'package:drift/drift.dart';

@DataClassName('MeasurementRow')
class Measurements extends Table {
  /// Device-generated stable identifier. The server never assigns it.
  TextColumn get id => text()();

  /// The metric's wire name, e.g. `blood_pressure`.
  TextColumn get metricType => text()();

  /// The primary value, in canonical units.
  RealColumn get value => real()();

  /// The unit of [value].
  TextColumn get unit => text()();

  /// The optional second component.
  RealColumn get secondaryValue => real().nullable()();

  /// The unit of [secondaryValue].
  TextColumn get secondaryUnit => text().nullable()();

  /// The optional third component.
  RealColumn get tertiaryValue => real().nullable()();

  /// The unit of [tertiaryValue].
  TextColumn get tertiaryUnit => text().nullable()();

  /// When the measurement happened, in UTC.
  DateTimeColumn get recordedAt => dateTime()();

  /// The local calendar day containing [recordedAt], at local midnight.
  ///
  /// Stored rather than computed so that day grouping survives timezone
  /// changes and daylight-saving transitions.
  DateTimeColumn get localDay => dateTime()();

  /// When the row was written to this device, in UTC.
  DateTimeColumn get createdAt => dateTime()();

  /// When the row was last modified, in UTC.
  DateTimeColumn get updatedAt => dateTime()();

  /// `manual`, `health_connect`, `imported`, or `derived`.
  TextColumn get source => text()();

  /// Whether the record has reached the server.
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  /// Set when the user deletes the record. Rows are never hard-deleted.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// The measurement context, serialised as JSON.
  TextColumn get contextJson => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
