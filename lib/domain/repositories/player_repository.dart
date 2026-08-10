import '../entities/player_profile.dart';

abstract class PlayerRepository {
  PlayerProfile getProfile();
  Future<void> updateProfile(PlayerProfile profile);
}