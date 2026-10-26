/// The Drift-backed implementation of [ProfileRepository].
library;

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/units/unit.dart';
import '../domain/health_profile.dart';
import '../domain/profile_repository.dart';

/// The id of the single local profile.
const String kLocalProfileId = 'me';

class ProfileRepositoryImpl implements ProfileRepository {
  const ProfileRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Future<HealthProfile> load() async {
    final query = _db.select(_db.profiles)
      ..where((row) => row.id.equals(kLocalProfileId));
    final rows = await query.get();
    if (rows.isEmpty) {
      return const HealthProfile(id: kLocalProfileId);
    }
    return _toDomain(rows.first);
  }

  @override
  Stream<HealthProfile> watch() {
    final query = _db.select(_db.profiles)
      ..where((row) => row.id.equals(kLocalProfileId));
    return query.watchSingleOrNull().map(
          (row) => row == null
              ? const HealthProfile(id: kLocalProfileId)
              : _toDomain(row),
        );
  }

  @override
  Future<void> save(HealthProfile profile) async {
    final now = DateTime.now().toUtc();
    await _db.into(_db.profiles).insertOnConflictUpdate(
          ProfilesCompanion.insert(
            id: profile.id,
            displayName: Value(profile.displayName),
            dateOfBirth: Value(profile.dateOfBirth),
            sex: Value(profile.sex),
            heightCm: Value(profile.heightCm),
            preferredMassUnit: Value(profile.preferredMassUnit.symbol),
            preferredLengthUnit: Value(profile.preferredLengthUnit.symbol),
            preferredTemperatureUnit:
                Value(profile.preferredTemperatureUnit.symbol),
            timeZone: Value(profile.timeZone),
            weightGoalKind: Value(profile.weightGoalKind.wireName),
            targetSystolic: Value(profile.targetSystolic),
            targetDiastolic: Value(profile.targetDiastolic),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  @override
  Future<List<HealthGoal>> goals() async {
    final query = _db.select(_db.goals)
      ..where((row) => row.active.equals(true));
    final rows = await query.get();
    return rows.map(_goalToDomain).toList();
  }

  @override
  Future<void> saveGoal(HealthGoal goal) async {
    final now = DateTime.now().toUtc();
    await _db.into(_db.goals).insertOnConflictUpdate(
          GoalsCompanion.insert(
            id: goal.id,
            metricType: goal.metricType,
            targetValue: goal.targetValue,
            unit: goal.unit.symbol,
            targetDate: Value(goal.targetDate),
            active: Value(goal.active),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  @override
  Future<void> deleteGoal(String id) async {
    await (_db.delete(_db.goals)..where((row) => row.id.equals(id))).go();
  }

  static HealthProfile _toDomain(Profile row) => HealthProfile(
        id: row.id,
        displayName: row.displayName,
        dateOfBirth: row.dateOfBirth,
        sex: row.sex,
        heightCm: row.heightCm,
        preferredMassUnit: _unitFromSymbol(row.preferredMassUnit),
        preferredLengthUnit: _unitFromSymbol(row.preferredLengthUnit),
        preferredTemperatureUnit:
            _unitFromSymbol(row.preferredTemperatureUnit),
        timeZone: row.timeZone,
        weightGoalKind:
            WeightGoalKind.fromWireName(row.weightGoalKind),
        targetSystolic: row.targetSystolic,
        targetDiastolic: row.targetDiastolic,
      );

  static HealthGoal _goalToDomain(Goal row) => HealthGoal(
        id: row.id,
        metricType: row.metricType,
        targetValue: row.targetValue,
        unit: _unitFromSymbol(row.unit),
        targetDate: row.targetDate,
        active: row.active,
      );

  static Unit _unitFromSymbol(String symbol) => Unit.values.firstWhere(
        (unit) => unit.symbol == symbol,
        orElse: () => Unit.percent,
      );
}
