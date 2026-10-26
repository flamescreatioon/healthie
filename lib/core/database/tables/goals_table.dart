/// A user-defined target for one metric.
///
/// Goals are optional and never prescriptive. Healthie does not recommend a
/// weight, and does not suggest a rate of change.
library;

import 'package:drift/drift.dart';

class Goals extends Table {
  TextColumn get id => text()();

  /// The metric's wire name.
  TextColumn get metricType => text()();

  /// The target value, in canonical units.
  RealColumn get targetValue => real()();

  /// The unit of [targetValue].
  TextColumn get unit => text()();

  /// An optional date by which the target should be reached.
  DateTimeColumn get targetDate => dateTime().nullable()();

  /// Whether the goal is currently shown.
  BoolColumn get active => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
