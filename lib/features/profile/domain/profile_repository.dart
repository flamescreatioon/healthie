/// The interface for the user's profile and goals.
library;

import 'health_profile.dart';

abstract interface class ProfileRepository {
  /// The stored profile, or a default one when nothing has been set up yet.
  Future<HealthProfile> load();

  /// Emits the profile whenever it changes.
  Stream<HealthProfile> watch();

  /// Writes the profile.
  Future<void> save(HealthProfile profile);

  /// The user's goals.
  Future<List<HealthGoal>> goals();

  /// Writes a goal.
  Future<void> saveGoal(HealthGoal goal);

  /// Removes a goal.
  Future<void> deleteGoal(String id);
}
