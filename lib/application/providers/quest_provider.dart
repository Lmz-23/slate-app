import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/hive/boxes/companion_state_box.dart';
import '../../data/repositories/companion_state_repository_impl.dart';
import '../../domain/entities/task.dart';
import '../../domain/repositories/companion_state_repository.dart';
import '../services/quest_calculator.dart';
import '../services/timezone_service.dart';
import 'now_provider.dart';
import 'player_provider.dart';
import 'settings_provider.dart';
import 'task_provider.dart';

final companionStateBoxProvider = Provider<CompanionStateBox>((ref) {
  throw UnimplementedError('Must be overridden');
});

final companionStateRepositoryProvider =
    Provider<CompanionStateRepositoryImpl>((ref) {
  return CompanionStateRepositoryImpl(ref.watch(companionStateBoxProvider));
});

/// Estado derivado de la quest diaria para la UI (F3, decisión C).
class QuestState extends Equatable {
  /// ¿La quest se muestra hoy? Decidida al inicio del día y persistente.
  final bool isVisible;

  /// Tareas completadas HOY (misma base que la alerta de racha).
  final int completedToday;

  /// ¿La quest de HOY ya fue reclamada?
  final bool isClaimed;

  /// Clave de día (`yyyy-M-d`) en la que se reclamó (solo diagnóstico/UI).
  final String? claimedOn;

  /// Clave de día (`yyyy-M-d`) de hoy.
  final String todayKey;

  const QuestState({
    required this.isVisible,
    required this.completedToday,
    required this.isClaimed,
    this.claimedOn,
    required this.todayKey,
  });

  /// Condición de éxito de la quest: visible, sin reclamar y con ≥3 tareas
  /// completadas hoy.
  bool get canClaim =>
      isVisible &&
      !isClaimed &&
      completedToday >= QuestCalculator.requiredCompletions;

  QuestState copyWith({
    bool? isVisible,
    int? completedToday,
    bool? isClaimed,
    String? claimedOn,
    String? todayKey,
  }) {
    return QuestState(
      isVisible: isVisible ?? this.isVisible,
      completedToday: completedToday ?? this.completedToday,
      isClaimed: isClaimed ?? this.isClaimed,
      claimedOn: claimedOn ?? this.claimedOn,
      todayKey: todayKey ?? this.todayKey,
    );
  }

  @override
  List<Object?> get props =>
      [isVisible, completedToday, isClaimed, claimedOn, todayKey];
}

/// Notifier de la quest diaria "Completa 3 tareas hoy" (F3, decisión C).
///
/// Reglas de producto aplicadas:
/// - **Visibilidad condicional**: la quest se muestra solo si hay ≥3 tareas
///   programadas para hoy. La decisión se toma UNA vez por día y se persiste
///   ([CompanionState.questVisibleOn/decision]): una vez visible, sigue
///   visible aunque después se borren tareas; si se decidió oculta, no
///   aparece aunque se añadan tareas.
/// - **Reset diario**: al cambiar de día, la quest queda sin reclamar y la
///   visibilidad se re-decide para el día nuevo.
/// - **Recompensa +25 XP**: reclamar exige acción explícita ([claim]) y solo
///   se puede una vez por día. Se usa [PlayerNotifier.addQuestXp], que
///   reutiliza `PlayerProfile.shownLevelUps`: si el +25 cruza un nivel ya
///   mostrado, [claim] devuelve `null` y la UI NO duplica el SnackBar.
class QuestNotifier extends StateNotifier<QuestState> {
  QuestNotifier({
    required CompanionStateRepository repository,
    required PlayerNotifier playerNotifier,
    required List<Task> Function() readTasks,
    required DateTime Function() readNow,
  })  : _repository = repository,
        _playerNotifier = playerNotifier,
        _readTasks = readTasks,
        _readNow = readNow,
        super(const QuestState(
          isVisible: false,
          completedToday: 0,
          isClaimed: false,
          todayKey: '',
        )) {
    _sync();
  }

  final CompanionStateRepository _repository;
  final PlayerNotifier _playerNotifier;
  final List<Task> Function() _readTasks;
  final DateTime Function() _readNow;

  /// Recalcula el estado derivado (visibilidad, completados de hoy, reclamada).
  /// Se invoca al arrancar, al cambiar tareas y al cambiar el día.
  void refresh() => _sync();

  /// Reclama la quest de hoy: +25 XP (una sola vez). Devuelve el nivel
  /// alcanzado si la quest produjo un level-up NUEVO (`null` en caso
  /// contrario) para que la UI muestre el SnackBar exactamente una vez.
  Future<int?> claim() async {
    if (!state.canClaim) return null;

    final levelUp = await _playerNotifier.addQuestXp();

    final current = _repository.getState();
    await _repository.updateState(current.copyWith(
      questClaimedOn: state.todayKey,
      updatedAt: _readNow(),
    ));
    _sync();
    return levelUp;
  }

  void _sync() {
    final now = _readNow();
    final todayKey = _dayKey(now);
    final companion = _repository.getState();

    final isClaimed = companion.questClaimedOn == todayKey;

    // Visibilidad: decidir una vez por día y persistir la decisión.
    var visible = false;
    if (companion.questVisibleOn == todayKey) {
      visible = companion.questVisibleDecision;
    } else {
      visible = QuestCalculator.shouldBeVisible(_readTasks(), now);
      _repository.updateState(companion.copyWith(
        questVisibleOn: todayKey,
        questVisibleDecision: visible,
        updatedAt: now,
      ));
    }

    final completedToday = QuestCalculator.completedCountOn(_readTasks(), now);

    state = QuestState(
      isVisible: visible,
      completedToday: completedToday,
      isClaimed: isClaimed,
      claimedOn: companion.questClaimedOn,
      todayKey: todayKey,
    );
  }

  static String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';
}

/// Proveedor de la quest diaria. Mantiene el estado fresco ante cambios de
/// tareas (completar/desmarcar) y de día (nowProvider).
final questProvider = StateNotifierProvider<QuestNotifier, QuestState>((ref) {
  final notifier = QuestNotifier(
    repository: ref.watch(companionStateRepositoryProvider),
    playerNotifier: ref.watch(playerProvider.notifier),
    readTasks: () => ref.read(tasksProvider),
    readNow: () =>
        TimezoneService.nowInTimezone(ref.read(settingsProvider).timezone),
  );
  ref.listen(tasksProvider, (_, __) => notifier.refresh());
  ref.listen(nowProvider, (_, __) => notifier.refresh());
  return notifier;
});