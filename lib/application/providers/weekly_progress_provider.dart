import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'now_provider.dart';
import 'task_provider.dart';

/// Progreso semanal agregado (bloque "Progreso semanal" de `/progress`,
/// Addendum 1 A10 + sistema-visual-fase3.md §2.3).
///
/// Extraído de `weekly_screen.dart` (`_calculateWeeklyProgress`, Fase 3a):
/// fracción de tareas COMPLETADAS sobre el total de las programadas en la
/// semana EN CURSO, desde el inicio de semana (domingo como día 0) hasta HOY
/// (los días futuros se excluyen a propósito, aún no tienen resultado).
///
/// Deliberadamente independiente de la semana NAVEGADA por
/// `selectedDateProvider`: siempre refleja el avance real de la semana en
/// curso, igual que antes de la fusión (mismo comportamiento, distinta
/// ubicación).
class WeeklyProgress extends Equatable {
  final int completed;
  final int total;

  const WeeklyProgress({required this.completed, required this.total});

  double get ratio => total > 0 ? completed / total : 0.0;

  @override
  List<Object?> get props => [completed, total];
}

final weeklyProgressProvider = Provider<WeeklyProgress>((ref) {
  final tasks = ref.watch(tasksProvider);
  final now = ref.watch(nowProvider).value ?? DateTime.now();

  if (tasks.isEmpty) return const WeeklyProgress(completed: 0, total: 0);

  final weekStart = now.subtract(Duration(days: now.weekday % 7));
  final weekTasks = tasks.where((t) {
    return t.scheduledDate.isAfter(weekStart.subtract(const Duration(days: 1))) &&
        t.scheduledDate.isBefore(now.add(const Duration(days: 1)));
  }).toList();

  final completed = weekTasks.where((t) => t.isCompleted).length;
  return WeeklyProgress(completed: completed, total: weekTasks.length);
});
