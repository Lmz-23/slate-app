import '../../domain/entities/task.dart';

/// Rango horario efectivo de una tarea, semántica `[start, end)`.
class TaskTimeRange {
  final DateTime start;
  final DateTime end;

  const TaskTimeRange({required this.start, required this.end});
}

/// Lógica PURA para derivar la hora de inicio/fin EFECTIVA de una tarea
/// (Addendum 2, A11).
///
/// No depende de Hive ni de Riverpod: recibe `Task` y devuelve `DateTime`s.
/// Mismo patrón que `ReminderScheduleCalculator`, con la misma trampa
/// documentada: `Task.scheduledTime` es un `DateTime` completo cuyo día NO es
/// autoritativo (las ocurrencias recurrentes conservan el día original de la
/// serie en `scheduledTime`); el día autoritativo es siempre
/// `Task.scheduledDate`.
class TaskScheduleCalculator {
  const TaskScheduleCalculator._();

  /// Instante de inicio efectivo: día de [Task.scheduledDate] + hora/minuto
  /// de [Task.scheduledTime]. `null` si la tarea no tiene horario (o es una
  /// subtarea, que nunca tiene `scheduledTime` propio).
  static DateTime? effectiveStart(Task task) {
    final time = task.scheduledTime;
    if (time == null) return null;
    return DateTime(
      task.scheduledDate.year,
      task.scheduledDate.month,
      task.scheduledDate.day,
      time.hour,
      time.minute,
    );
  }

  /// Instante de fin efectivo: [effectiveStart] + [Task.durationMinutes].
  /// `null` si no hay inicio resoluble o si la duración es `null`/`<= 0`
  /// (tarea legacy sin fin conocido).
  static DateTime? effectiveEnd(Task task) {
    final start = effectiveStart(task);
    final duration = task.durationMinutes;
    if (start == null || duration == null || duration <= 0) return null;
    return start.add(Duration(minutes: duration));
  }

  /// Rango horario efectivo `[start, end)`. `null` para tareas sin horario,
  /// subtareas o tareas legacy sin duración conocida.
  static TaskTimeRange? effectiveRange(Task task) {
    final start = effectiveStart(task);
    final end = effectiveEnd(task);
    if (start == null || end == null) return null;
    return TaskTimeRange(start: start, end: end);
  }
}
