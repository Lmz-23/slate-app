import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/quest_calculator.dart';
import 'now_provider.dart';
import 'task_provider.dart';

/// Estado derivado de progreso diario (Decisión A3).
///
/// [totalToday] es el TOTAL REAL de tareas programadas hoy (no el umbral fijo
/// de [QuestCalculator.requiredCompletions]): la etiqueta "N de M tareas
/// completadas hoy" debe mostrar información honesta, no el umbral de la
/// quest (que puede ser distinto, ver A3/RG14).
class DailyProgress extends Equatable {
  final int completedToday;
  final int totalToday;

  const DailyProgress({
    required this.completedToday,
    required this.totalToday,
  });

  /// Meta diaria cumplida (sistema-visual-fase3.md §3): hay al menos una
  /// tarea programada hoy Y todas están completadas.
  bool get isGoalMet => totalToday > 0 && completedToday >= totalToday;

  @override
  List<Object?> get props => [completedToday, totalToday];
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Provider derivado de solo lectura (Decisión A3): NO persiste nada nuevo,
/// se recalcula a partir de [tasksProvider] y [nowProvider].
final dailyProgressProvider = Provider<DailyProgress>((ref) {
  final tasks = ref.watch(tasksProvider);
  final now = ref.watch(nowProvider).value ?? DateTime.now();

  // Misma base que QuestCalculator.shouldBeVisible (excluye subtareas), pero
  // SIN el umbral de 3: aquí se cuenta el total real programado hoy.
  final totalToday =
      tasks.where((t) => !t.isSubtask && _sameDay(t.scheduledDate, now)).length;
  final completedToday = QuestCalculator.completedCountOn(tasks, now);

  return DailyProgress(completedToday: completedToday, totalToday: totalToday);
});
