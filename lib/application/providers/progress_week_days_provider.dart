import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'task_provider.dart';

/// Días (lunes→domingo) de la semana NAVEGADA en `/progress`, derivados de
/// `selectedDateProvider` (Addendum 1 A10: la navegación de semanas de
/// Progreso comparte el mismo selector de fecha que Home — acoplamiento
/// preexistente documentado, no se corrige aquí).
///
/// Extraído de `weekly_screen.dart` (`_getWeekDays`, Fase 3a) para no dejarlo
/// como método privado de `ProgressScreen`.
final progressWeekDaysProvider = Provider<List<DateTime>>((ref) {
  final selectedDate = ref.watch(selectedDateProvider);
  final monday = selectedDate.subtract(Duration(days: (selectedDate.weekday - 1) % 7));
  return List.generate(7, (i) => monday.add(Duration(days: i)));
});
