import 'package:flutter/foundation.dart';

import '../../domain/entities/badge.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/user_settings.dart';
import '../../domain/enums/badge_type.dart';
import 'fortnight_calculator.dart';
import 'notification_ids.dart';
import 'reminder_schedule_calculator.dart';
import 'reminder_scheduler.dart';
import 'thematic_texts_resolver.dart';

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
/// - Cierre de jornada (`0x60000003`) según la decisión C: reporta el día al
///   siguiente reset.
/// - Alerta de racha en peligro (`0x60000004`) según la decisión B (F2): se
///   programa HOY a las 12:00 del mediodía cuando la racha está activa (≥3) y
///   aún no se completó ninguna misión; se cancela al completar la primera del
///   día, si la racha cae bajo 3, si las notificaciones están OFF o si la hora
///   ya pasó (patrón Fix A: nunca programar al pasado).
///
/// Si se inyecta un [resolver] de textos temáticos (Slate System), los títulos
/// y cuerpos se toman de él SIEMPRE (el resolver es la fuente única; nunca
/// devuelve `null`). Si no hay resolver se usan los textos por defecto, de modo
/// que ningún test ni comportamiento existente cambia.
class ReminderManager {
  const ReminderManager({
    required ReminderScheduler scheduler,
    ThematicTextsResolver? resolver,
  })  : _scheduler = scheduler,
        _resolver = resolver;

  final ReminderScheduler _scheduler;
  final ThematicTextsResolver? _resolver;

  /// Sincroniza el recordatorio de UNA tarea con su estado y los ajustes.
  ///
  /// Si las notificaciones están desactivadas, la tarea está completada o no
  /// tiene horario → CANCELA el recordatorio (idempotente). También CANCELA si
  /// el disparo calculado ya pasó respecto a [now]: nunca se programa al
  /// pasado (el plugin lanza `ArgumentError` con fechas pasadas). Mismo patrón
  /// de defensa que [syncDayClosure].
  Future<void> syncTaskReminder(
    Task task,
    UserSettings settings, {
    required DateTime now,
  }) async {
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
    if (!fireTime.isAfter(now)) {
      await _scheduler.cancel(reminderIdForTask(task.id));
      return;
    }

    // CUELLO DE BOTELLO RAF (guardado de tareas recurrentes ~8-12 s): no se
    // programa una notificación por CADA instancia futura de una serie (una
    // serie diaria → ~365 `zonedSchedule` nativos secuenciales). Las
    // ocurrencias fuera de la ventana se dejan SIN programar (ni cancelar: no
    // hay nada que limpiar); el re-sync diario del `DailyReminderController`
    // las programa cuando entren en la ventana. La generación de instancias
    // en BD no cambia.
    if (ReminderScheduleCalculator.isFarFutureRecurringOccurrence(task, now)) {
      return;
    }

    final themed = _resolver?.resolveTaskReminder(task);
    await _scheduler.schedule(
      id: reminderIdForTask(task.id),
      title: themed?.title ?? 'Recordatorio',
      body: themed?.body ?? ReminderScheduleCalculator.taskReminderBody(task),
      fireTime: fireTime,
    );
  }

  /// Cancela directamente el recordatorio de la tarea [taskId].
  Future<void> cancelTaskReminder(String taskId) =>
      _scheduler.cancel(reminderIdForTask(taskId));

  /// Re-sincroniza los recordatorios de TODAS las tareas (usado al iniciar la
  /// app y al cambiar ajustes globales de notificaciones: margen o toggle).
  ///
  /// Cada tarea se procesa en su propio try/catch (mismo patrón que
  /// `TasksNotifier._syncReminderForTask`): un error de plugin en UNA tarea no
  /// debe abortar la sincronización de las demás. [now] evita programar
  /// disparos ya pasados (ver [syncTaskReminder]).
  Future<void> syncAllTaskReminders(
    List<Task> tasks,
    UserSettings settings, {
    required DateTime now,
  }) async {
    for (final task in tasks) {
      try {
        await syncTaskReminder(task, settings, now: now);
      } catch (e) {
        debugPrint(
            'ReminderManager: error sincronizando recordatorio de ${task.id}: $e');
      }
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
      final themed = _resolver?.resolveMorningSummary(
        ReminderScheduleCalculator.pendingCountOn(allTasks, today),
      );
      await _scheduler.schedule(
        id: morningDailyReminderId,
        title: themed?.title ?? 'Tareas pendientes hoy',
        body: themed?.body ??
            ReminderScheduleCalculator.morningReminderBody(
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
      final themed = _resolver?.resolveEveningSummary(
        ReminderScheduleCalculator.pendingCountOn(allTasks, today),
      );
      await _scheduler.schedule(
        id: eveningDailyReminderId,
        title: themed?.title ?? 'Resumen de hoy',
        body: themed?.body ??
            ReminderScheduleCalculator.eveningReminderBody(
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

  /// Decide y programa/cancela el cierre de jornada (`0x60000003`).
  ///
  /// Reglas (decisión C):
  /// - La notificación de la jornada X se programa para disparar a
  ///   `dayResetHour` del día X+1 y reporta el resultado del día X
  ///   (completadas/total, pendientes, racha actual y hito alcanzado).
  /// - Se programa SOLO si: notificaciones activas, cierre activo, y hubo
  ///   tareas programadas en la jornada reportada (o racha > 0).
  /// - Se CANCELA si: toggles desactivados, sin tareas en la jornada (y racha
  ///   0), o la hora de disparo ya pasó (defensa: nunca programar al pasado).
  ///
  /// [currentStreak] y [milestone] los aporta el controlador (leyendo el
  /// estado de racha); el hito es el nivel de rango alcanzado a la racha
  /// actual, que se incluye en el reporte como "hito desbloqueado si hubo".
  Future<void> syncDayClosure({
    required DateTime now,
    required List<Task> allTasks,
    required UserSettings settings,
    int currentStreak = 0,
    BadgeType? milestone,
  }) async {
    final enabled = settings.notificationsEnabled && settings.enableDayClosure;
    final fireTime = ReminderScheduleCalculator.nextDayReset(
      now,
      settings.dayResetHour,
    );

    // Toggle off o el disparo ya pasó (defensa): cancelar.
    if (!enabled || !fireTime.isAfter(now)) {
      await _scheduler.cancel(dayClosureReminderId);
      return;
    }

    final jornada = ReminderScheduleCalculator.jornadaEndingAtNextReset(
      now,
      settings.dayResetHour,
    );
    final hadTasks = ReminderScheduleCalculator.hasTasksOn(allTasks, jornada);
    if (!hadTasks && currentStreak <= 0) {
      await _scheduler.cancel(dayClosureReminderId);
      return;
    }

    final stats = DayClosureStats(
      jornada: jornada,
      total: ReminderScheduleCalculator.scheduledCountOn(allTasks, jornada),
      completed: ReminderScheduleCalculator.completedCountOn(allTasks, jornada),
      currentStreak: currentStreak,
      milestone: milestone,
    );
    final themed = _resolver?.resolveDayClosure(stats);
    await _scheduler.schedule(
      id: dayClosureReminderId,
      title: themed?.title ?? 'Cierre de jornada',
      body: themed?.body ?? ReminderScheduleCalculator.dayClosureBody(stats),
      fireTime: fireTime,
    );
  }

  /// Cancela directamente el cierre de jornada.
  Future<void> cancelDayClosure() => _scheduler.cancel(dayClosureReminderId);

  /// Decide y programa/cancela la alerta de racha en peligro (`0x60000004`)
  /// para HOY a las 12:00 del MEDIODÍA (decisión B, F2).
  ///
  /// Reglas:
  /// - Se programa SOLO si: notificaciones activas, racha activa ≥ 3 días
  ///   ([ReminderScheduleCalculator.streakAtRiskMinStreak]) y NO se ha
  ///   completado ninguna misión hoy (usa la lógica existente de conteo de
  ///   completados del día).
  /// - Se CANCELA si: toggles desactivados, racha < 3, ya se completó la
  ///   primera tarea del día, o la hora de disparo ya pasó (patrón Fix A:
  ///   nunca programar al pasado).
  ///
  /// [currentStreak] lo aporta el controlador leyendo `streakProvider`.
  Future<void> syncStreakAtRiskReminder({
    required DateTime now,
    required List<Task> allTasks,
    required UserSettings settings,
    required int currentStreak,
  }) async {
    final today = DateTime(now.year, now.month, now.day);
    final fireTime = DateTime(
      today.year,
      today.month,
      today.day,
      streakAtRiskReminderHour,
      0,
    );

    final shouldSchedule = settings.notificationsEnabled &&
        ReminderScheduleCalculator.shouldFireStreakAtRiskReminder(
          allTasks: allTasks,
          day: today,
          currentStreak: currentStreak,
        ) &&
        fireTime.isAfter(now);

    if (shouldSchedule) {
      final themed = _resolver?.resolveStreakAtRisk(currentStreak);
      await _scheduler.schedule(
        id: streakAtRiskReminderId,
        title: themed?.title ?? 'Racha en peligro',
        body: themed?.body ??
            ReminderScheduleCalculator.streakAtRiskBody(currentStreak),
        fireTime: fireTime,
      );
    } else {
      await _scheduler.cancel(streakAtRiskReminderId);
    }
  }

  /// Cancela directamente la alerta de racha en peligro.
  Future<void> cancelStreakAtRiskReminder() =>
      _scheduler.cancel(streakAtRiskReminderId);

  /// Decide y programa/cancela el resumen quincenal del Sistema
  /// (`0x60000005`, F3 decisión D).
  ///
  /// Cadencia QUINCENAL (días fijos 1 y 16 a las 20:00). El resumen dispara
  /// tras `fireTime` y reporta la quincena recién terminada:
  /// - el disparo del día 16 reporta la quincena-1 (1..15 de ese mes);
  /// - el disparo del día 1 reporta la quincena-2 del mes ANTERIOR
  ///   (16..último día del mes).
  ///
  /// Patrón igual al cierre de jornada: programar, disparar tras `fireTime` y
  /// re-programar el siguiente periodo (al volver a decidir,
  /// [FortnightCalculator.nextFireTime] devuelve el siguiente disparo futuro).
  /// Defensa Fix A: si la hora ya pasó, cancela en lugar de programar al
  /// pasado. Se CANCELA solo cuando las notificaciones están desactivadas.
  Future<void> syncFortnightSummary({
    required DateTime now,
    required List<Task> allTasks,
    required UserSettings settings,
    required int currentStreak,
    required int level,
    required int totalXp,
    required List<Badge> badges,
  }) async {
    final fireTime = FortnightCalculator.nextFireTime(
      now,
      hour: fortnightSummaryReminderHour,
    );

    if (!settings.notificationsEnabled || !fireTime.isAfter(now)) {
      await _scheduler.cancel(fortnightSummaryReminderId);
      return;
    }

    final period = FortnightCalculator.periodForFireTime(fireTime);
    final stats = FortnightSummaryStats(
      period: period,
      completedCount: FortnightCalculator.completedCountIn(allTasks, period),
      currentStreak: currentStreak,
      level: level,
      totalXp: totalXp,
      badgesUnlockedCount:
          FortnightCalculator.badgesUnlockedIn(badges, period),
    );
    final themed = _resolver?.resolveFortnightSummary(stats);
    await _scheduler.schedule(
      id: fortnightSummaryReminderId,
      title: themed?.title ?? 'Resumen quincenal',
      body: themed?.body ?? FortnightCalculator.fortnightBody(stats),
      fireTime: fireTime,
    );
  }

  /// Cancela directamente el resumen quincenal.
  Future<void> cancelFortnightSummary() =>
      _scheduler.cancel(fortnightSummaryReminderId);
}
