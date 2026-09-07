import '../../domain/entities/player_profile.dart';
import '../../domain/repositories/player_repository.dart';
import '../hive/boxes/player_progress_box.dart';

class PlayerRepositoryImpl implements PlayerRepository {
  final PlayerProgressBox _box;

  PlayerRepositoryImpl(this._box);

  @override
  PlayerProfile getProfile() => _box.getProfile();

  @override
  Future<void> updateProfile(PlayerProfile profile) =>
      _box.updateProfile(profile);
}