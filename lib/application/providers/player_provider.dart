import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/hive/boxes/player_progress_box.dart';
import '../../data/repositories/player_repository_impl.dart';
import '../../domain/entities/player_profile.dart';
import '../../domain/enums/task_priority.dart';
import '../../domain/enums/xp_event_type.dart';
import '../services/player_xp_calculator.dart';

final playerProgressBoxProvider = Provider<PlayerProgressBox>((ref) {
  throw UnimplementedError('Must be overridden');
});

final playerRepositoryProvider = Provider<PlayerRepositoryImpl>((ref) {
  return PlayerRepositoryImpl(ref.watch(playerProgressBoxProvider));
});

/// Estado del Jugador (nivel/XP). Complementa a racha e insignias: no las
/// sustituye ni depende de ellas.
final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerProfile>((ref) {
  return PlayerNotifier(ref.watch(playerRepositoryProvider));
});

/// Notifier del perfil de Jugador (F2).
///
/// Reglas de producto aplicadas:
/// - Al COMPLETAR una tarea se suman +10/+15/+20 según su prioridad; al
///   DESMARCARLA se restan los mismos puntos (simetría anti-exploit).
/// - El XP puede bajar, pero el NIVEL NUNCA: el nivel cacheado solo crece.
/// - El retorno de cada método es el nivel alcanzado si hubo un level-up
///   NUEVO (null en caso contrario), para que la UI muestre el SnackBar
///   "◆ Nivel subió" exactamente una vez por nivel ([PlayerProfile.shownLevelUps]
///   registra la transición consumida).
/// - El diseño admite eventos de SUBTAREA (F4) desde ya: métodos separados
///   por [XpEventType] (+2 XP por subtarea), aunque la UI no los usa hoy.
class PlayerNotifier extends StateNotifier<PlayerProfile> {
  final PlayerRepositoryImpl _repository;

  PlayerNotifier(this._repository) : super(_repository.getProfile());

  void refresh() {
    state = _repository.getProfile();
  }

  /// COMPLETAR tarea: +XP según su prioridad. Devuelve el nivel alcanzado si
  /// hubo level-up NUEVO (o `null`).
  Future<int?> addTaskXp(TaskPriority priority) => _applyDelta(
        PlayerXpCalculator.xpForPriority(priority),
        XpEventType.task,
      );

  /// DESMARCAR tarea: RESTA el XP ganado. El XP total baja, el nivel NO.
  Future<int?> removeTaskXp(TaskPriority priority) => _applyDelta(
        -PlayerXpCalculator.xpForPriority(priority),
        XpEventType.task,
      );

  /// F4 (preparado): +2 XP por subtarea completada. Sin UI todavía.
  Future<int?> addSubtaskXp() => _applyDelta(
        PlayerXpCalculator.subtaskXp,
        XpEventType.subtask,
      );

  /// F4 (preparado): -2 XP al desmarcar una subtarea.
  Future<int?> removeSubtaskXp() => _applyDelta(
        -PlayerXpCalculator.subtaskXp,
        XpEventType.subtask,
      );

  /// F3 (decisión C): +25 XP al reclamar la quest diaria.
  ///
  /// La quest no se desreclama (el evento es unidireccional), pero el método
  /// reutiliza la misma maquinaria de [PlayerProfile.shownLevelUps]: si el +25
  /// cruza un nivel cuya transición YA fue consumida (p. ej. alcanzado antes
  /// con tareas), devuelve `null` y la UI NO muestra un SnackBar duplicado.
  Future<int?> addQuestXp() => _applyDelta(
        PlayerXpCalculator.questXp,
        XpEventType.quest,
      );

  /// Aplica el delta de XP (positivo o negativo) de un [evento], persiste en
  /// Hive y actualiza el estado al instante (reflejo inmediato).
  ///
  /// El nivel resultante es el MÁXIMO entre el nivel previo (cacheado,
  /// irreversible) y el nivel derivado del nuevo XP. Un level-up es NUEVO
  /// cuando el nivel derivado supera al previo cacheado; en ese caso se
  /// registra la transición en [PlayerProfile.shownLevelUps] para que la UI
  /// la muestre una sola vez.
  Future<int?> _applyDelta(int delta, XpEventType event) async {
    final newTotalXp = math.max(0, state.totalXp + delta);
    final computedLevel = PlayerXpCalculator.levelForXp(newTotalXp);
    final previousLevel = state.level;
    final effectiveLevel = math.max(previousLevel, computedLevel);

    final shownLevelUps = Set<int>.from(state.shownLevelUps);
    final isLevelUp = computedLevel > previousLevel;
    if (isLevelUp) {
      shownLevelUps.add(computedLevel);
    }

    final updated = PlayerProfile(
      id: state.id,
      totalXp: newTotalXp,
      level: effectiveLevel,
      shownLevelUps: shownLevelUps,
      updatedAt: DateTime.now(),
    );

    await _repository.updateProfile(updated);
    state = updated;

    return isLevelUp ? computedLevel : null;
  }
}