import '../../domain/entities/task.dart';

/// Lógica PURA del sistema de recordatorios.
///
/// No depende de plugins de dispositivo ni de Riverpod: solo recibe `Task`,
/// `DateTime` y enteros, y devuelve decisiones/instantes. Esto la hace
/// directamente testeable sin mockear el sistema.
class ReminderScheduleCalculator {
  const ReminderScheduleCalculator._();

  /// ¿Ambas fechas pertenecen al mismo día (año/mes/día)?
  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Fecha/hora EFECTIVA de la tarea: combina la fecha programada
  /// (`Task.scheduledDate`) con la hora (`Task.scheduledTime`).
  ///
  /// IMPORTANTE: `Task.scheduledTime` es un `DateTime` COMPLETO cuyo día suele
  /// coincidir con la fecha en la que se creó/guardó la tarea. En las
  /// ocurrencias de series recurrentes solo cambia `scheduledDate`; usar
  /// `scheduledTime` directamente dispararía el recordatorio en el día
  /// original de la serie. Por eso siempre se reconstruye día+hora.
  static DateTime effectiveDateTime(Task task) {
    final time = task.scheduledTime;
    if (time == null) return task.scheduledDate;
    return DateTime(
      task.scheduledDate.year,
      task.scheduledDate.month,
      task.scheduledDate.day,
      time.hour,
      time.minute,
    );
  }

  /// Hora efectiva de disparo del recordatorio de la tarea aplicando el margen
  /// [leadTimeMinutes]: el aviso ocurre `leadTimeMinutes` ANTES de la hora de
  /// la tarea. Con margen 0 (default de producto) el aviso llega justo a la
  /// hora de la tarea.
  static DateTime taskReminderFireTime(Task task, int leadTimeMinutes) =>
      effectiveDateTime(task).subtract(Duration(minutes: leadTimeMinutes));

  /// Próxima ocurrencia del recordatorio diario a [hour]:00 respecto a [now].
  ///
  /// Devuelve HOY a [hour]:00 si la hora aún no ha pasado (cadena temporal
  /// estrictamente futura); en caso contrario devuelve MAÑANA a [hour]:00. Los
  /// minutos se fuerzan a 0: el producto configura solo la hora.
  static DateTime nextDailyReminderTime(DateTime now, int hour) {
    final today = DateTime(now.year, now.month, now.day, hour, 0);
    return today.isAfter(now) ? today : today.add(const Duration(days: 1));
  }

  /// ¿Existe alguna tarea PENDIENTE (sin completar) programada en [day]?
  static bool hasPendingTasksOn(List<Task> tasks, DateTime day) =>
      tasks.any((t) => !t.isCompleted && _sameDay(t.scheduledDate, day));

  /// Número de tareas PENDIENTES programadas en [day].
  static int pendingCountOn(List<Task> tasks, DateTime day) => tasks
      .where((t) => !t.isCompleted && _sameDay(t.scheduledDate, day))
      .length;

  /// ¿No se ha completado NINGUNA tarea en [day]?
  ///
  /// Se basa en `Task.completedAt` (instante real en el que se marcó como
  /// completada), no en la fecha programada: una tarea de ayer marcada hoy
  /// cuenta como "completada hoy".
  static bool noTasksCompletedOn(List<Task> allTasks, DateTime day) =>
      !allTasks.any((t) =>
          t.isCompleted &&
          t.completedAt != null &&
          _sameDay(t.completedAt!, day));

  /// Condición del resumen de las 10:00 (P3): hay tareas pendientes HOY (con
  /// o sin horario).
  static bool shouldFireMorningReminder({
    required List<Task> allTasks,
    required DateTime day,
  }) =>
      hasPendingTasksOn(allTasks, day);

  /// Condición del resumen de las 19:00 (P5): hay tareas pendientes HOY Y no
  /// se ha completado ninguna tarea en todo el día.
  static bool shouldFireEveningReminder({
    required List<Task> allTasks,
    required DateTime day,
  }) =>
      hasPendingTasksOn(allTasks, day) && noTasksCompletedOn(allTasks, day);

  /// Cuerpo del recordatorio de tarea, p. ej.:
  /// `Recordatorio: "Comprar leche" a las 14:00`.
  static String taskReminderBody(Task task) {
    final time = effectiveDateTime(task);
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return 'Recordatorio: "${task.title}" a las $hh:$mm';
  }

  /// Cuerpo del resumen de las 10:00.
  static String morningReminderBody(int pendingCount) {
    return 'Tienes $pendingCount tarea${pendingCount == 1 ? '' : 's'} pendiente${pendingCount == 1 ? '' : 's'} para hoy.';
  }

  /// Cuerpo del resumen de las 19:00.
  static String eveningReminderBody(int pendingCount) {
    return 'Hoy no has completado ninguna tarea. Te quedan $pendingCount pendiente${pendingCount == 1 ? '' : 's'}.';
  }
}
