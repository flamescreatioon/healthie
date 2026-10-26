/// Riverpod providers for the profile feature.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../domain/health_profile.dart';
import '../../domain/profile_repository.dart';

/// The stored profile, updated whenever it changes.
final profileProvider = StreamProvider<HealthProfile>(
  (ref) => ref.watch(profileRepositoryProvider).watch(),
);

/// The user's goals.
final goalsProvider = FutureProvider<List<HealthGoal>>(
  (ref) => ref.watch(profileRepositoryProvider).goals(),
);

/// Writes to the profile.
///
/// Reads come from [profileProvider]; this only performs writes, so there is
/// no second copy of the state to keep in sync.
final profileControllerProvider = Provider<ProfileController>(
  (ref) => ProfileController(ref.watch(profileRepositoryProvider)),
);

class ProfileController {
  const ProfileController(this._repository);

  final ProfileRepository _repository;

  /// Writes the profile.
  Future<void> save(HealthProfile profile) => _repository.save(profile);

  /// Writes a goal.
  Future<void> saveGoal(HealthGoal goal) => _repository.saveGoal(goal);

  /// Removes a goal.
  Future<void> deleteGoal(String id) => _repository.deleteGoal(id);
}
