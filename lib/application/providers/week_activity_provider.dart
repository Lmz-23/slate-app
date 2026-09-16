import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/streak_calculator.dart';
import 'now_provider.dart';
import 'task_provider.dart';

/// Provider derivado de solo lectura (Decisión A3): actividad de la semana
/// calendario actual (lunes→domingo), recalculando
/// [StreakCalculator.calculate] `.activeDays` desde [tasksProvider].
///
/// Se rechaza deliberadamente persistir `activeDays` en `Streak` (obligaría a
/// tocar `StreakAdapter`/`backup_codec`, ver A3): este provider es puro y se
/// recalcula en cada cambio de tareas o de día.
///
/// Devuelve una lista de 7 booleanos, posición 0 = lunes, posición 6 =
/// domingo.
final weekActivityProvider = Provider<List<bool>>((ref) {
  final tasks = ref.watch(tasksProvider);
  final now = ref.watch(nowProvider).value ?? DateTime.now();

  final calculation = StreakCalculator.calculate(tasks: tasks, now: now);

  final today = DateTime(now.year, now.month, now.day);
  final monday = today.subtract(Duration(days: today.weekday - 1));

  return List<bool>.generate(7, (i) {
    final day = monday.add(Duration(days: i));
    final utcDay = DateTime.utc(day.year, day.month, day.day);
    return calculation.activeDays.contains(utcDay);
  });
});
