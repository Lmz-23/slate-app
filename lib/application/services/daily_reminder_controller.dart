import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/task.dart';
import '../../domain/entities/user_settings.dart';
import '../../domain/enums/badge_type.dart';
import '../providers/now_provider.dart';
import '../providers/player_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/streak_provider.dart';
import '../providers/task_provider.dart';
import 'notification_service.dart';
import 'reminder_manager.dart';
import 'timezone_service.dart';

/// Coordina los RECORDATORIOS DIARIOS (P3/P5) con el ciclo de vida de la app y
/// los eventos de estado:
///
/// - Al ARRANCAR la app (cuando se construye este controlador): reprograma los
///   resúmenes del día (10:00/19:00) y reconcilia los recordatorios de TODAS
///   las tareas existentes (backfill de tareas creadas antes de que existieran
///   notificaciones).
/// - Cuando cambian las TAREAS (crear/completar/borrar/editar): vuelve a
///   decidir si programar el resumen de HOY. Esto implementa la cancelación
///   de las 19:00: al completar la primera tarea del día, `syncDailyReminders`
///   deja de cumplir la condición y cancela el disparo.
/// - Cuando cambian los AJUSTES de notificaciones (toggle global, margen,
///   horas del resumen, zona horaria): re-aplica todo (tareas + resumen).
/// - Cuando cambia el DÍA (el `nowProvider` refresca cada 30 s): reprograma
///   los resúmenes del nuevo día.
///
/// F2/F3: el controlador también coordina la alerta de racha en peligro
/// (`0x60000004`, 12:00) y el resumen quincenal del Sistema (`0x60000005`,
/// día 1 y 16 a las 20:00), ambos con secciones try/catch propias (Fix A+B).
///
/// La programación con `zonedSchedule` es de disparo único para HOY, por lo que
/// no hay un "periodic" nativo que cubra la 19:00 condicional; el controlador
/// garantiza que cada día se (re)decida y reprograme. Limitación documentada:
/// si la app no se abre en un día, ese día no se (re)programa (el arranque del
/// siguiente día o el cambio de día con la app abierta lo restaura).
class DailyReminderController {
  DailyReminderController(this._ref, this._manager, this._service) {
    _ref.listen(nowProvider, (previous, next) => _onNowChanged());
    _ref.listen(tasksProvider, (previous, next) => _onTasksChanged());
    _ref.listen(streakProvider, (previous, next) => _onStreakChanged());
    _ref.listen(
      settingsProvider,
      (previous, next) => _onSettingsChanged(previous, next),
    );
    _scheduleEverything();
  }

  final Ref _ref;
  final ReminderManager _manager;
  final NotificationService _service;

  DateTime? _lastScheduledDay;
  String _lastNotificationSignature = '';

  /// Firma de los ajustes que afectan a las notificaciones. Permite ignorar
  /// cambios irrelevantes (tema, nombre de usuario, ...) sin reprogramar.
  ///
  /// Incluye los toggles de sonido/vibración/badge (Mejora 2): al cambiarlos
  /// se vuelve a agendar TODO para que los nuevos detalles del canal queden
  /// aplicados también a las programaciones pendientes.
  ///
  /// Incluye el opt-in de textos con IA y el cierre de jornada: al cambiarlos
  /// se re-agenda para que los títulos/cuerpos temáticos queden aplicados en
  /// las programaciones pendientes.
  String _notificationSignature(UserSettings s) =>
      '${s.notificationsEnabled}|${s.notificationLeadTimeMinutes}|'
      '${s.dailyReminderEnabled}|${s.dailyReminderHour1}|'
      '${s.dailyReminderHour2}|${s.timezone}|'
      '${s.notificationSound}|${s.notificationVibration}|'
      '${s.notificationBadge}|${s.enableDayClosure}|'
      '${s.useAIThematicTexts}';

  DateTime _now() {
    final settings = _ref.read(settingsProvider);
    return TimezoneService.nowInTimezone(settings.timezone);
  }

  String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  void _onNowChanged() {
    final key = _dayKey(_now());
    if (key != _dayKey(_lastScheduledDay ?? _now())) {
      _scheduleEverything();
    }
  }

  void _onTasksChanged() {
    // Al cambiar tareas solo se redeciden los resúmenes del día (2 ids).
    // Los recordatorios individuales YA se sincronizan en TasksNotifier.
    _syncDailyRemindersOnly();
  }

  void _onStreakChanged() {
    // La racha se recalcula DESPUÉS de los cambios de tareas (TaskSection
    // llama a recalculate tras toggleComplete). Al escuchar el cambio se
    // vuelve a decidir con la racha NUEVA: si cayó bajo 3, la alerta de racha
    // en peligro (0x60000004) queda cancelada aunque el evento de tareas la
    // hubiera procesado con la racha anterior.
    _syncDailyRemindersOnly();
  }

  void _onSettingsChanged(UserSettings? previous, UserSettings settings) {
    _service.updateTimezone(settings.timezone);

    // Mejora 2: si cambió sonido/vibración/badge, recrea el canal al instante
    // para que la nueva configuración se aplique a los próximos recordatorios.
    // El canal en Android 8+ se fija al CREARLO; `createNotificationChannel`
    // con el mismo id y nueva config lo actualiza.
    final channelChanged = previous == null ||
        previous.notificationSound != settings.notificationSound ||
        previous.notificationVibration != settings.notificationVibration ||
        previous.notificationBadge != settings.notificationBadge;
    if (channelChanged) {
      unawaited(_service.updateChannelForSettings(settings));
    }

    if (_notificationSignature(settings) == _lastNotificationSignature) return;
    _scheduleEverything();
  }

  /// Re-decide TODO: recordatorios de todas las tareas + resúmenes del día.
  void _scheduleEverything() {
    unawaited(_scheduleEverythingAsync());
  }

  Future<void> _scheduleEverythingAsync() async {
    final settings = _ref.read(settingsProvider);
    final tasks = _ref.read(tasksProvider);
    final now = _now();

    // Secciones independientes con try/catch PROPIO: un fallo en una (p. ej.
    // una tarea cuyo `zonedSchedule` lanza) NO debe saltarse las otras
    // (resúmenes 10:00/19:00 y cierre de jornada). Fix A+B: coordenada con el
    // fix de `syncAllTaskReminders` que cancela disparos pasados en vez de
    // programarlos.
    try {
      await _manager.syncAllTaskReminders(tasks, settings, now: now);
    } catch (e) {
      debugPrint(
          'DailyReminderController: error en recordatorios de tareas: $e');
    }
    try {
      // NOTA: si las notificaciones están desactivadas, syncDailyReminders
      // cancela en lugar de programar.
      await _manager.syncDailyReminders(
        now: now,
        allTasks: tasks,
        settings: settings,
      );
    } catch (e) {
      debugPrint('DailyReminderController: error en resumen diario: $e');
    }
    try {
      await _syncDayClosureIfEnabled(now, tasks, settings);
    } catch (e) {
      debugPrint(
          'DailyReminderController: error en cierre de jornada: $e');
    }
    try {
      // F2 (decisión B): alerta de racha en peligro a las 12:00 si procede.
      await _syncStreakAtRisk(now, tasks, settings);
    } catch (e) {
      debugPrint('DailyReminderController: error en alerta de racha: $e');
    }
    try {
      // F3 (decisión D): resumen quincenal del Sistema (1/16 a las 20:00).
      await _syncFortnightSummary(now, tasks, settings);
    } catch (e) {
      debugPrint('DailyReminderController: error en resumen quincenal: $e');
    }

    _lastScheduledDay = now;
    _lastNotificationSignature = _notificationSignature(settings);
  }

  /// Re-decide el cierre de jornada solo si el toggle está activo (evita leer
  /// el estado de racha en el caso común desactivado). Si está desactivado,
  /// [ReminderManager.syncDayClosure] cancela el id sin depender de la racha.
  Future<void> _syncDayClosureIfEnabled(
    DateTime now,
    List<Task> tasks,
    UserSettings settings,
  ) async {
    if (!settings.enableDayClosure) {
      await _manager.syncDayClosure(
        now: now,
        allTasks: tasks,
        settings: settings,
      );
      return;
    }
    final streak = _ref.read(streakProvider);
    await _manager.syncDayClosure(
      now: now,
      allTasks: tasks,
      settings: settings,
      currentStreak: streak.currentStreak,
      milestone: _currentMilestone(streak.currentStreak),
    );
  }

  /// Hito de rango más alto alcanzado a la racha actual (null si racha 0).
  static BadgeType? _currentMilestone(int streakDays) {
    final all = BadgeType.badgesUpTo(streakDays);
    return all.isEmpty ? null : all.last;
  }

  /// Decide la alerta de racha en peligro (0x60000004) con la racha actual.
  ///
  /// El controlador ya lee `streakProvider` (para el cierre de jornada); aquí
  /// se lo reutiliza y se delega la programación/cancelación al manager, que
  /// aplica la condición (racha ≥ 3 y sin completados hoy) y la defensa de no
  /// programar al pasado.
  Future<void> _syncStreakAtRisk(
    DateTime now,
    List<Task> tasks,
    UserSettings settings,
  ) async {
    final streak = _ref.read(streakProvider);
    await _manager.syncStreakAtRiskReminder(
      now: now,
      allTasks: tasks,
      settings: settings,
      currentStreak: streak.currentStreak,
    );
  }

  /// Solo re-decide los resúmenes diarios (10:00/19:00). Barato y se llama en
  /// cada cambio de tareas.
  void _syncDailyRemindersOnly() {
    unawaited(_syncDailyRemindersOnlyAsync());
  }

  Future<void> _syncDailyRemindersOnlyAsync() async {
    final settings = _ref.read(settingsProvider);
    final tasks = _ref.read(tasksProvider);
    final now = _now();
    try {
      await _manager.syncDailyReminders(
        now: now,
        allTasks: tasks,
        settings: settings,
      );
    } catch (e) {
      debugPrint('DailyReminderController: error en resumen diario: $e');
    }
    try {
      await _syncDayClosureIfEnabled(now, tasks, settings);
    } catch (e) {
      debugPrint(
          'DailyReminderController: error en cierre de jornada: $e');
    }
    try {
      await _syncStreakAtRisk(now, tasks, settings);
    } catch (e) {
      debugPrint('DailyReminderController: error en alerta de racha: $e');
    }
    try {
      await _syncFortnightSummary(now, tasks, settings);
    } catch (e) {
      debugPrint('DailyReminderController: error en resumen quincenal: $e');
    }
    _lastScheduledDay = now;
  }

  /// Decide el resumen quincenal (0x60000005) con los datos actuales: racha,
  /// Jugador (nivel/XP) e insignias desbloqueadas. La programación/cancelación
  /// se delega al manager, que aplica la cadencia fija (día 1 y 16, 20:00) y
  /// la defensa de no programar al pasado (patrón Fix A).
  Future<void> _syncFortnightSummary(
    DateTime now,
    List<Task> tasks,
    UserSettings settings,
  ) async {
    final streak = _ref.read(streakProvider);
    final player = _ref.read(playerProvider);
    final badges = _ref.read(badgesProvider);
    await _manager.syncFortnightSummary(
      now: now,
      allTasks: tasks,
      settings: settings,
      currentStreak: streak.currentStreak,
      level: player.level,
      totalXp: player.totalXp,
      badges: badges,
    );
  }

  void dispose() {}
}