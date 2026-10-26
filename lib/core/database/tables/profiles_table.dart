/// The local health profile.
///
/// Healthie is a single-user, local-first app for now. The table still has a
/// primary key and an `id` so that an account-backed multi-user build does not
/// require a schema migration.
library;

import 'package:drift/drift.dart';

class Profiles extends Table {
  /// The profile identifier. Constant `me` for the local profile.
  TextColumn get id => text()();

  /// The name shown in the greeting.
  TextColumn get displayName => text().nullable()();

  /// Optional date of birth.
  DateTimeColumn get dateOfBirth => dateTime().nullable()();

  /// Optional sex, voluntarily supplied.
  TextColumn get sex => text().nullable()();

  /// Optional height in centimetres, used to compute BMI.
  RealColumn get heightCm => real().nullable()();

  /// Preferred mass unit: `kg` or `lb`.
  TextColumn get preferredMassUnit => text().withDefault(const Constant('kg'))();

  /// Preferred length unit: `cm` or `in`.
  TextColumn get preferredLengthUnit =>
      text().withDefault(const Constant('cm'))();

  /// Preferred temperature unit: `°C` or `°F`.
  TextColumn get preferredTemperatureUnit =>
      text().withDefault(const Constant('°C'))();

  /// The IANA time-zone name, used for display and export.
  TextColumn get timeZone => text().nullable()();

  /// The user's weight intention: `maintain`, `lose`, `gain`, or `none`.
  TextColumn get weightGoalKind => text().withDefault(const Constant('none'))();

  /// A clinician-provided systolic target, in mmHg.
  IntColumn get targetSystolic => integer().nullable()();

  /// A clinician-provided diastolic target, in mmHg.
  IntColumn get targetDiastolic => integer().nullable()();

  /// When the row was written, in UTC.
  DateTimeColumn get createdAt => dateTime()();

  /// When the row was last modified, in UTC.
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
