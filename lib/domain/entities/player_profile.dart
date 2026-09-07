import 'package:equatable/equatable.dart';

/// Perfil de Jugador persistido (caja Hive `player_progress`, singleton).
///
/// F2 (Nivel de Jugador + XP):
/// - [totalXp] es la FUENTE DE VERDAD del XP acumulado. Crece al completar
///   tareas (+10/+15/+20 por prioridad) y se reduce al desmarcarlas (simetría
///   anti-exploit, igual que la racha resta).
/// - [level] es el nivel DERIVADO/cacheado. Se calcula a partir del XP con la
///   curva `xpRequerido(nivel) = 100 · nivel²`, pero NUNCA baja: aunque el XP
///   pueda reducirse al desmarcar, el nivel alcanzado permanece (irreversible).
/// - [shownLevelUps] registra las transiciones de nivel ya consumidas por la
///   UI (SnackBar "◆ Nivel subió") para que cada nivel se notifique UNA sola
///   vez, incluso si el usuario desmarca y vuelve a marcar la misma tarea.
/// - [updatedAt] conserva el instante de la última actualización.
class PlayerProfile extends Equatable {
  final String id;
  final int totalXp;
  final int level;
  final Set<int> shownLevelUps;
  final DateTime updatedAt;

  const PlayerProfile({
    required this.id,
    this.totalXp = 0,
    this.level = 1,
    this.shownLevelUps = const {},
    required this.updatedAt,
  });

  PlayerProfile copyWith({
    String? id,
    int? totalXp,
    int? level,
    Set<int>? shownLevelUps,
    DateTime? updatedAt,
  }) {
    return PlayerProfile(
      id: id ?? this.id,
      totalXp: totalXp ?? this.totalXp,
      level: level ?? this.level,
      shownLevelUps: shownLevelUps ?? this.shownLevelUps,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        totalXp,
        level,
        ...(shownLevelUps.toList()..sort()),
        updatedAt,
      ];
}