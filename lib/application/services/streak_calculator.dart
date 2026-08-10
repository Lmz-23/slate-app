import '../../domain/entities/task.dart';

/// Resultado del cálculo derivado de la racha.
class StreakCalculation {
  /// Racha actual: cadena consecutiva de días activos que termina en el día
  /// activo más reciente ≤ hoy.
  final int currentStreak;

  /// Mejor racha histórica. Solo crece: se fusiona el máximo derivado del
  /// historial con el valor persistido previo.
  final int longestStreak;

  /// Día ancla de la racha actual (día activo más reciente ≤ hoy), como
  /// medianoche UTC (`DateTime.utc(y, m, d)`). `null` si no hay días activos.
  final DateTime? lastCompletedDate;

  /// Conjunto de días activos (día calendario con ≥1 tarea completada según
  /// `scheduledDate` con clamp de futuras a hoy). Se expone para diagnóstico
  /// y para permitir futuras optimizaciones/caché sin cambiar la API.
  final Set<DateTime> activeDays;

  const StreakCalculation({
    required this.currentStreak,
    required this.longestStreak,
    required this.lastCompletedDate,
    required this.activeDays,
  });
}

/// Calcula la racha de forma DERIVADA a partir del historial de tareas
/// completadas (fuente de verdad), en lugar de usar un contador incremental.
///
/// Reglas de producto aplicadas:
/// - **R1a**: al completar una tarea con fecha pasada, se acredita su fecha
///   programada (`scheduledDate`). Las tareas con fecha hoy/futura se acreditan
///   como "hoy" (clamp: `effectiveDay = scheduledDate < hoy ? scheduledDate : hoy`).
/// - **R2a**: el resultado NO depende del orden de marcado: se deriva
///   íntegramente del conjunto de días con al menos una tarea completada.
/// - **R3b**: el mismo cálculo sirve al completar y al descompletar; al
///   desmarcar una tarea, la racha baja si el conjunto de días activos se
///   reduce (y `longestStreak` nunca baja).
///
/// Los días se representan como medianoche UTC (`DateTime.utc(y, m, d)`): la
/// comparación de días es exacta e independiente de la zona horaria y de DST.
class StreakCalculator {
  /// Calcula la racha derivada.
  ///
  /// [tasks] es la lista completa de tareas (completadas y pendientes) del
  /// proveedor de tareas; solo se consideran las completadas.
  /// [now] es el instante actual en la zona horaria configurada (p. ej.
  /// `TimezoneService.nowInTimezone(...)` o `ref.read(nowProvider).value`).
  /// [previousLongestStreak] es el `longestStreak` persistido, para que el
  /// máximo histórico solo crezca aunque una racha previa ya no exista en el
  /// historial actual.
  static StreakCalculation calculate({
    required List<Task> tasks,
    required DateTime now,
    int previousLongestStreak = 0,
  }) {
    final today = DateTime.utc(now.year, now.month, now.day);

    // Día activo: día calendario (año/mes/día) con al menos una tarea
    // completada, acreditando scheduledDate (R1a) con clamp de futuras a hoy.
    // F4-fix H2 (regla de producto): las SUBTAREAS no activan la racha (no
    // son "misiones" del Slate System); solo cuentan tareas con
    // `isSubtask == false`.
    final activeDays = <DateTime>{};
    for (final task in tasks) {
      if (task.isSubtask) continue;
      if (!task.isCompleted) continue;
      final taskDay = DateTime.utc(
        task.scheduledDate.year,
        task.scheduledDate.month,
        task.scheduledDate.day,
      );
      final effectiveDay = taskDay.isBefore(today) ? taskDay : today;
      activeDays.add(effectiveDay);
    }

    // Racha actual: cadena consecutiva de días activos que termina en el día
    // activo más reciente ≤ hoy (regla de anclaje).
    //
    // Si hoy aún no tiene tareas completadas pero ayer sí, la racha NO cae a 0:
    // permanece viva anclada al último día activo. Esto es coherente con el
    // comportamiento previo de la app (la racha solo cambiaba al completar) y
    // con la definición de la racha como "días reales con tareas completadas".
    // La "expiración" se detecta en la siguiente completación tras un hueco
    // ≥ 1 día: el recálculo reancla al nuevo día y la racha se recompone.
    final sortedDays = activeDays.toList()..sort();
    final anchor = sortedDays.isEmpty ? null : sortedDays.last;

    var currentStreak = 0;
    if (anchor != null) {
      var day = anchor;
      while (activeDays.contains(day)) {
        currentStreak++;
        day = day.subtract(const Duration(days: 1));
      }
    }

    // Racha más larga: solo crece. Se fusiona el máximo derivado del historial
    // con el valor persistido (que pudo corresponder a una racha ya deshecha).
    final computedLongest = _maxConsecutiveRun(sortedDays);
    final longestStreak = computedLongest > previousLongestStreak
        ? computedLongest
        : previousLongestStreak;

    return StreakCalculation(
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      lastCompletedDate: anchor,
      activeDays: activeDays,
    );
  }

  /// Longitud de la mayor secuencia de días consecutivos dentro de [sortedDays]
  /// (orden ascendente). `0` si la lista está vacía.
  static int _maxConsecutiveRun(List<DateTime> sortedDays) {
    if (sortedDays.isEmpty) return 0;
    var best = 1;
    var run = 1;
    for (var i = 1; i < sortedDays.length; i++) {
      final prev = sortedDays[i - 1];
      final curr = sortedDays[i];
      final diff = curr.difference(prev).inDays;
      if (diff == 1) {
        run++;
        if (run > best) best = run;
      } else {
        run = 1;
      }
    }
    return best;
  }
}
