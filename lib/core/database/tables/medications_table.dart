/// Medications table.
library;

import 'package:drift/drift.dart';

@DataClassName('MedicationRow')
class Medications extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();

  TextColumn get dosageInstructions => text()();

  /// Comma-separated local times, e.g. "08:00,20:00".
  TextColumn get schedule => text()();

  DateTimeColumn get startDate => dateTime()();

  DateTimeColumn get endDate => dateTime().nullable()();

  BoolColumn get active => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
