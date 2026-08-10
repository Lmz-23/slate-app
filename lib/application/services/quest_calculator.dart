import '../../domain/entities/task.dart';

/// Lógica PURA de la quest diaria "Completa 3 tareas hoy" (F3, decisión C).
///
/// No depende de Hive ni de Riverpod: recibe `Task`/`DateTime` y devuelve
/// decisiones/cifras, por lo que es directamente testeable con fechas fijas.
class QuestCalculator {
  const QuestCalculator._();

  /// Número de tareas a completar HOY para poder reclamar la quest.
  static const int requiredCompletions = 3;

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// ¿Debe MOSTRARSE la quest hoy? Solo si hay **≥ 3 tareas programadas** para
  /// el día [day] (pendientes o ya completadas, con horario o sin él). La
  /// decisión se toma una vez por día y después persiste (ver
  /// [CompanionState.questVisibleDecision]): borrar tareas no la revierte.
  static bool shouldBeVisible(List<Task> tasks, DateTime day) =>
      tasks.where((t) => _sameDay(t.scheduledDate, day)).length >=
      requiredCompletions;

  /// Tareas completadas en [day] según `Task.completedAt` (el instante REAL de
  /// marcado, no la fecha programada). Es la misma base que usa la alerta de
  /// racha en peligro (`noTasksCompletedOn`), para que quest y racha cuenten
  /// "completadas hoy" de forma coherente.
  static int completedCountOn(List<Task> tasks, DateTime day) => tasks
      .where((t) =>
          t.isCompleted && t.completedAt != null && _sameDay(t.completedAt!, day))
      .length;
}