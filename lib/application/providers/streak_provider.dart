import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/streak.dart';
import '../../domain/entities/badge.dart';
import '../../domain/entities/task.dart';
import '../../domain/enums/badge_type.dart';
import '../../data/hive/boxes/streaks_box.dart';
import '../../data/hive/boxes/badges_box.dart';
import '../../data/repositories/streak_repository_impl.dart';
import '../../data/repositories/badge_repository_impl.dart';
import '../services/streak_calculator.dart';

final streaksBoxProvider = Provider<StreaksBox>((ref) {
  throw UnimplementedError('Must be overridden');
});

final badgesBoxProvider = Provider<BadgesBox>((ref) {
  throw UnimplementedError('Must be overridden');
});

final streakRepositoryProvider = Provider<StreakRepositoryImpl>((ref) {
  return StreakRepositoryImpl(ref.watch(streaksBoxProvider));
});

final badgeRepositoryProvider = Provider<BadgeRepositoryImpl>((ref) {
  return BadgeRepositoryImpl(ref.watch(badgesBoxProvider));
});

final streakProvider = StateNotifierProvider<StreakNotifier, Streak>((ref) {
  return StreakNotifier(
    ref.watch(streakRepositoryProvider),
    ref.watch(badgesProvider.notifier),
  );
});

final badgesProvider = StateNotifierProvider<BadgesNotifier, List<Badge>>((ref) {
  return BadgesNotifier(ref.watch(badgeRepositoryProvider));
});

class StreakNotifier extends StateNotifier<Streak> {
  final StreakRepositoryImpl _streakRepository;
  final BadgesNotifier _badgesNotifier;

  StreakNotifier(this._streakRepository, this._badgesNotifier)
      : super(_streakRepository.getStreak());

  void refresh() {
    state = _streakRepository.getStreak();
  }

  /// Recalcula la racha derivada a partir del historial de tareas completadas.
  ///
  /// Fuente de verdad: [tasks] (el proveedor de tareas). Solo se consideran
  /// las tareas completadas, acreditando su `scheduledDate` (R1a) con clamp de
  /// fechas futuras a hoy.
  ///
  /// Se invoca al COMPLETAR una tarea Y al DESCOMPLETARLA (R3b): el cálculo es
  /// simétrico y no depende del orden de marcado (R2a), por lo que un mismo
  /// método sirve para ambas transiciones. Al desmarcar, la racha baja si el
  /// conjunto de días activos se reduce; `longestStreak` nunca baja.
  ///
  /// [now] debe ser el instante actual en la zona horaria configurada
  /// (p. ej. `TimezoneService.nowInTimezone(settings.timezone)` o
  /// `ref.read(nowProvider).value`). Si es `null` se usa `DateTime.now()`.
  ///
  /// `lastCompletedDate` se guarda como medianoche UTC
  /// (`DateTime.utc(y, m, d)`), es decir, la representación del DÍA
  /// CALENDARIO independiente de la zona horaria; Hive la restaura de forma
  /// estable aunque la zona del dispositivo difiera de la configurada, y la
  /// comparación de días es exacta sin problemas de DST. `updatedAt` sí
  /// conserva el instante original ([now], que puede ser un `TZDateTime`).
  Future<void> recalculate({
    required List<Task> tasks,
    DateTime? now,
  }) async {
    final current = now ?? DateTime.now();

    final calculation = StreakCalculator.calculate(
      tasks: tasks,
      now: current,
      previousLongestStreak: state.longestStreak,
    );

    // Se construye el Streak directamente (no copyWith) para permitir que
    // lastCompletedDate quede en null cuando no existen días activos.
    final updatedStreak = Streak(
      id: state.id,
      currentStreak: calculation.currentStreak,
      longestStreak: calculation.longestStreak,
      lastCompletedDate: calculation.lastCompletedDate,
      updatedAt: current,
    );

    await _streakRepository.updateStreak(updatedStreak);
    state = updatedStreak;

    // Al subir la racha se desbloquean TODOS los umbrales ≤ nuevo valor;
    // al bajar NUNCA se retiran (insignias irreversibles). El desbloqueo se
    // delega en el BadgesNotifier, que persiste en Hive Y actualiza su estado
    // en memoria para que badgesProvider (y BadgeVault) lo reflejen al instante.
    if (calculation.currentStreak > 0) {
      await _badgesNotifier.unlockBadges(calculation.currentStreak);
    }
  }
}

class BadgesNotifier extends StateNotifier<List<Badge>> {
  final BadgeRepositoryImpl _repository;
  final _uuid = const Uuid();

  BadgesNotifier(this._repository) : super(_repository.getAll());

  void refresh() {
    state = _repository.getAll();
  }

  /// Desbloquea todas las insignias con umbral ≤ [streakDays] que aún no se
  /// poseen, persistiéndolas en Hive y actualizando el estado en memoria.
  ///
  /// Idempotente: si una insignia ya existe no se reescribe ni se duplica en
  /// el estado. Al bajar la racha NUNCA se retiran insignias: solo se añaden.
  ///
  /// Es la ÚNICA vía de desbloqueo: al combinar persistencia + actualización
  /// de estado en un mismo método, cualquier consumidor de `badgesProvider`
  /// (p. ej. BadgeVault) refleja las insignias nuevas al instante, sin
  /// depender de llamadas externas a [refresh].
  Future<void> unlockBadges(int streakDays) async {
    final ownedTypes = state.map((b) => b.type).toSet();
    final newlyUnlocked = <Badge>[];
    for (final badgeType in BadgeType.badgesUpTo(streakDays)) {
      if (ownedTypes.contains(badgeType)) continue;
      final badge = Badge(
        id: _uuid.v4(),
        type: badgeType,
        name: badgeType.name,
        iconName: badgeType.iconName,
        unlockedAt: DateTime.now(),
        isDisplayed: true,
      );
      await _repository.add(badge);
      newlyUnlocked.add(badge);
    }
    if (newlyUnlocked.isNotEmpty) {
      state = [...state, ...newlyUnlocked];
    }
  }
}