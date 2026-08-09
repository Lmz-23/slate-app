import '../../domain/entities/task.dart';
import '../../domain/entities/user_settings.dart';
import 'notification_ids.dart';
import 'reminder_schedule_calculator.dart';
import 'reminder_scheduler.dart';

/// Orquesta la relación entre las tareas/ajustes y las notificaciones.
///
/// Reglas de producto aplicadas (P2/P3/P5):
/// - Recordatorio de tarea con horario: se programa a `hora - margen`. Con
///   margen 0 (default) el aviso llega justo a la hora de la tarea.
/// - Se CANCELA al completar la tarea, al borrarla, o si pierde el horario.
/// - Al editar fecha/hora se reprograma con el MISMO id (el id se deriva del
///   id de la tarea), por lo que la nueva programación reemplaza a la anterior
///   sin necesidad de cancelación previa.
/// - Resumen diario (10:00 y 19:00) según las decisiones P3/P5.
class ReminderManager {
  const ReminderManager({required ReminderScheduler scheduler})
      : _scheduler = scheduler;

  final ReminderScheduler _scheduler;

  /// Sincroniza el recordatorio de UNA tarea con su estado y los ajustes.
  ///
  /// Si las notificaciones están desactivadas, la tarea está completada o no
  /// tiene horario → CANCELA el recordatorio (idempotente).
  Future<void> syncTaskReminder(Task task, UserSettings settings) async {
    if (!settings.notificationsEnabled ||
        task.isCompleted ||
        task.scheduledTime == null) {
      await _scheduler.cancel(reminderIdForTask(task.id));
      return;
    }

    final fireTime = ReminderScheduleCalculator.taskReminderFireTime(
      task,
      settings.notificationLeadTimeMinutes,
    );
    await _scheduler.schedule(
      id: reminderIdForTask(task.id),
      title: 'Recordatorio',
      body: ReminderScheduleCalculator.taskReminderBody(task),
      fireTime: fireTime,
    );
  }

  /// Cancela directamente el recordatorio de la tarea [taskId].
  Future<void> cancelTaskReminder(String taskId) =>
      _scheduler.cancel(reminderIdForTask(taskId));

  /// Re-sincroniza los recordatorios de TODAS las tareas (usado al iniciar la
  /// app y al cambiar ajustes globales de notificaciones: margen o toggle).
  Future<void> syncAllTaskReminders(
    List<Task> tasks,
    UserSettings settings,
  ) async {
    for (final task in tasks) {
      await syncTaskReminder(task, settings);
    }
  }

  /// Decide y ejecuta la programación/cancelación de los resúmenes diarios de
  /// HOY (10:00 y 19:00) según las decisiones P3/P5:
  ///
  ///   - 10:00: se programa SOLO si hay tareas pendientes hoy y la hora aún no
  ///            ha pasado. Sino, se cancela (evita un disparo tarde).
  ///   - 19:00: se programa SOLO si hay tareas pendientes hoy, NO se ha
  ///            completado ninguna tarea hoy y la hora aún no ha pasado. Al
  ///            completar la primera tarea del día, el controlador vuelve aquí
  ///            y cancela el disparo de las 19:00.
  ///   - Si `notificationsEnabled` o `dailyReminderEnabled` es false se
  ///     cancelan ambos.
  Future<void> syncDailyReminders({
    required DateTime now,
    required List<Task> allTasks,
    required UserSettings settings,
  }) async {
    final enabled =
        settings.notificationsEnabled && settings.dailyReminderEnabled;
    final today = DateTime(now.year, now.month, now.day);

    // 10:00
    final morningTime = DateTime(
      today.year,
      today.month,
      today.day,
      settings.dailyReminderHour1,
      0,
    );
    final fireMorning = enabled &&
        ReminderScheduleCalculator.shouldFireMorningReminder(
          allTasks: allTasks,
          day: today,
        ) &&
        morningTime.isAfter(now);

    if (fireMorning) {
      await _scheduler.schedule(
        id: morningDailyReminderId,
        title: 'Tareas pendientes hoy',
        body: ReminderScheduleCalculator.morningReminderBody(
          ReminderScheduleCalculator.pendingCountOn(allTasks, today),
        ),
        fireTime: morningTime,
      );
    } else {
      await _scheduler.cancel(morningDailyReminderId);
    }

    // 19:00
    final eveningTime = DateTime(
      today.year,
      today.month,
      today.day,
      settings.dailyReminderHour2,
      0,
    );
    final fireEvening = enabled &&
        ReminderScheduleCalculator.shouldFireEveningReminder(
          allTasks: allTasks,
          day: today,
        ) &&
        eveningTime.isAfter(now);

    if (fireEvening) {
      await _scheduler.schedule(
        id: eveningDailyReminderId,
        title: 'Resumen de hoy',
        body: ReminderScheduleCalculator.eveningReminderBody(
          ReminderScheduleCalculator.pendingCountOn(allTasks, today),
        ),
        fireTime: eveningTime,
      );
    } else {
      await _scheduler.cancel(eveningDailyReminderId);
    }
  }

  /// Cancela ambos recordatorios diarios (al desactivarlos en Ajustes).
  Future<void> cancelDailyReminders() async {
    await _scheduler.cancel(morningDailyReminderId);
    await _scheduler.cancel(eveningDailyReminderId);
  }
}
