/// Medication logs table.
library;

import 'package:drift/drift.dart';

@DataClassName('MedicationLogRow')
class MedicationLogs extends Table {
  TextColumn get id => text()();

  TextColumn get medicationId => text()();

  DateTimeColumn get scheduledAt => dateTime()();

  /// taken / skipped / missed
  TextColumn get status => text()();

  DateTimeColumn get recordedAt => dateTime()();

  TextColumn get notes => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
