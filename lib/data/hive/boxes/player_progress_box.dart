import 'package:hive_flutter/hive_flutter.dart';
import '../../../domain/entities/player_profile.dart';

/// Caja Hive `player_progress` con el perfil de Jugador (singleton).
///
/// Backfill (decisión A): al abrir por primera vez se crea el perfil de un
/// usuario existente con nivel 1 y 0 XP (no se recrea histórico).
class PlayerProgressBox {
  static const String _boxName = 'player_progress';
  static const String _singletonId = 'main_player';
  late Box<PlayerProfile> _box;

  Future<void> init() async {
    _box = await Hive.openBox<PlayerProfile>(_boxName);
  }

  Box<PlayerProfile> get box => _box;

  PlayerProfile getProfile() {
    final profile = _box.get(_singletonId);
    if (profile == null) {
      final fresh = PlayerProfile(
        id: _singletonId,
        totalXp: 0,
        level: 1,
        shownLevelUps: const {},
        updatedAt: DateTime.now(),
      );
      _box.put(_singletonId, fresh);
      return fresh;
    }
    return profile;
  }

  Future<void> updateProfile(PlayerProfile profile) async {
    await _box.put(_singletonId, profile);
  }
}