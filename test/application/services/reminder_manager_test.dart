import 'package:flutter_test/flutter_test.dart';

import 'package:slate_app/application/services/notification_ids.dart';
import 'package:slate_app/application/services/reminder_manager.dart';
import 'package:slate_app/application/services/reminder_schedule_calculator.dart';
import 'package:slate_app/application/services/reminder_scheduler.dart';
import 'package:slate_app/application/services/thematic_texts_resolver.dart';
import 'package:slate_app/domain/entities/badge.dart';
import 'package:slate_app/domain/entities/task.dart';
import 'package:slate_app/domain/entities/user_settings.dart';
import 'package:slate_app/domain/enums/badge_type.dart';

/// Fake del Contrato de bajo nivel: registra programaciones y cancelaciones sin
/// depender del plugin nativo.
class FakeScheduler implements ReminderScheduler {
  final scheduled = <int, ({DateTime fireTime, String title, String body})>{};
  final cancelled = <int>[];

  /// Simula el plugin real (`zonedSchedule`): cuando es true, `schedule` lanza
  /// `ArgumentError` si [fireTime] no es estrictamente posterior a
  /// [nowProvider()] — el comportamiento exacto que motivó el fix A (nunca
  /// programar al pasado). Default false para no alterar los 143 tests previos.
  bool throwOnPastFireTime = false;

  /// "Ahora" con el que el fake valida `fireTime` cuando
  /// [throwOnPastFireTime] está activo. Por defecto usa `DateTime.now()`.
  DateTime Function() nowProvider;

  FakeScheduler({DateTime Function()? nowProvider})
      : nowProvider = nowProvider ?? DateTime.now;

  @override
  Future<void> init({required String timezone}) async {}

  @override
  Future<bool> canScheduleExactNotifications() async => true;

  @override
  Future<bool> requestExactAlarmsPermission() async => true;

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime fireTime,
  }) async {
    if (throwOnPastFireTime && !fireTime.isAfter(nowProvider())) {
      throw ArgumentError('fireTime must be in the future');
    }
    scheduled[id] = (fireTime: fireTime, title: title, body: body);
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    scheduled.remove(id);
  }
}

Task _task(
  String id,
  DateTime scheduledDate, {
  DateTime? scheduledTime,
  bool isCompleted = false,
  DateTime? completedAt,
}) {
  return Task(
    id: id,
    title: 'Tarea $id',
    scheduledDate: scheduledDate,
    scheduledTime: scheduledTime,
    isCompleted: isCompleted,
    completedAt: completedAt,
    createdAt: scheduledDate,
  );
}

UserSettings _settings({int lead = 0, bool notificationsEnabled = true}) =>
    UserSettings(
        notificationLeadTimeMinutes: lead,
        notificationsEnabled: notificationsEnabled);

/// Instante de una tarea: 14:00 del día.
DateTime get _atTwo => DateTime(2026, 1, 15, 14, 0);

/// Instante anterior a los `fireTime` de los tests (08:00 del 15/01).
DateTime get _earlyMorning => DateTime(2026, 1, 15, 8, 0);

void main() {
  late FakeScheduler scheduler;
  late ReminderManager manager;

  setUp(() {
    scheduler = FakeScheduler();
    manager = ReminderManager(scheduler: scheduler);
  });

  // Jornada de ejemplo con tareas completadas y pendientes (decisión C).
  final tareasHoy = [
    _task('a', DateTime(2026, 1, 15)),
    _task('b', DateTime(2026, 1, 15), isCompleted: true),
  ];

  group('syncTaskReminder (P2)', () {
    test('programa solo si hay horario y notificaciones activas', () async {
      final task = _task('a', DateTime(2026, 1, 15), scheduledTime: _atTwo);
      await manager.syncTaskReminder(task, _settings(), now: _earlyMorning);

      expect(scheduler.scheduled.keys, contains(reminderIdForTask('a')));
      expect(
        scheduler.scheduled[reminderIdForTask('a')]!.fireTime,
        DateTime(2026, 1, 15, 14, 0),
      );
      expect(
        scheduler.scheduled[reminderIdForTask('a')]!.body,
        ReminderScheduleCalculator.taskReminderBody(task),
      );
    });

    test('aplica el margen: con 15 min el disparo es las 13:45', () async {
      final task = _task('t', DateTime(2026, 1, 15), scheduledTime: _atTwo);
      await manager.syncTaskReminder(
          task, _settings(lead: 15), now: _earlyMorning);

      expect(
        scheduler.scheduled[reminderIdForTask('t')]!.fireTime,
        DateTime(2026, 1, 15, 13, 45),
      );
    });

    test('el id es determinista (misma tarea -> mismo id)', () {
      expect(reminderIdForTask('abc'), reminderIdForTask('abc'));
      expect(reminderIdForTask('abc'), isNot(reminderIdForTask('abd')));
      expect(reminderIdForTask('abc') < 0x7FFFFFFF, isTrue);
    });

    test('tarea recurrente: el disparo usa el día de la OCURRENCIA', () async {
      // scheduledTime conserva el día del padre (1 Ene); scheduledDate es el
      // día de la ocurrencia (16 Ene). El recordatorio debe ser 16 Ene 08:00.
      final occurrence = _task(
        'child',
        DateTime(2026, 1, 16),
        scheduledTime: DateTime(2026, 1, 1, 8, 0),
      );
      await manager.syncTaskReminder(occurrence, _settings(), now: _earlyMorning);
      expect(
        scheduler.scheduled[reminderIdForTask('child')]!.fireTime,
        DateTime(2026, 1, 16, 8, 0),
      );
    });

    test('tarea completada -> CANCELA (no notifica)', () async {
      final task = _task(
        't',
        DateTime(2026, 1, 15),
        scheduledTime: _atTwo,
        isCompleted: true,
        completedAt: DateTime(2026, 1, 15, 10, 0),
      );
      await manager.syncTaskReminder(task, _settings(), now: _earlyMorning);
      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.cancelled, contains(reminderIdForTask('t')));
    });

    test('tarea sin horario -> CANCELA', () async {
      final task = _task('t', DateTime(2026, 1, 15));
      await manager.syncTaskReminder(task, _settings(), now: _earlyMorning);
      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.cancelled, contains(reminderIdForTask('t')));
    });

    test('notificaciones desactivadas -> CANCELA aunque tenga horario',
        () async {
      final task = _task('t', DateTime(2026, 1, 15), scheduledTime: _atTwo);
      await manager.syncTaskReminder(
          task, _settings(notificationsEnabled: false), now: _earlyMorning);
      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.cancelled, contains(reminderIdForTask('t')));
    });

    test('fireTime pasado -> CANCELA, no lanza (defensa Fix A)', () async {
      final task = _task('t', DateTime(2026, 1, 15), scheduledTime: _atTwo);
      // now 15:00: el disparo (14:00) ya pasó → cancelar en vez de programar.
      await manager.syncTaskReminder(
          task, _settings(), now: DateTime(2026, 1, 15, 15, 0));

      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.cancelled, contains(reminderIdForTask('t')));
    });

    test('fireTime pasado por margen -> CANCELA', () async {
      final task = _task('t', DateTime(2026, 1, 15), scheduledTime: _atTwo);
      // lead 60 → fireTime 13:00; now 13:45 → ya pasó al restar el margen.
      await manager.syncTaskReminder(task, _settings(lead: 60),
          now: DateTime(2026, 1, 15, 13, 45));

      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.cancelled, contains(reminderIdForTask('t')));
    });
  });

  group('syncAllTaskReminders / cancelTaskReminder', () {
    test('re-sincroniza todas las tareas del listado', () async {
      final tasks = [
        _task('a', DateTime(2026, 1, 15), scheduledTime: _atTwo),
        _task('b', DateTime(2026, 1, 16),
            scheduledTime: DateTime(2026, 1, 16, 9, 0)),
        _task('c', DateTime(2026, 1, 17)), // sin horario
      ];
      await manager.syncAllTaskReminders(tasks, _settings(), now: _earlyMorning);
      expect(scheduler.scheduled.keys, {
        reminderIdForTask('a'),
        reminderIdForTask('b'),
      });
    });

    test('mezcla de una pasada y una futura: cancela la pasada y programa '
        'la futura', () async {
      final tasks = [
        _task('past', DateTime(2026, 1, 15), scheduledTime: _atTwo),
        _task('future', DateTime(2026, 1, 16),
            scheduledTime: DateTime(2026, 1, 16, 9, 0)),
      ];
      await manager.syncAllTaskReminders(
          tasks, _settings(), now: DateTime(2026, 1, 15, 15, 0));

      expect(scheduler.scheduled.keys, {reminderIdForTask('future')});
      expect(scheduler.cancelled, contains(reminderIdForTask('past')));
    });

    test('una tarea que lanza no aborta la sincronización de las demás '
        '(Fix B)', () async {
      // Simula la carrera real entre el `now` de la app y el reloj del
      // dispositivo en el plugin: el gestor (ahora 08:00) agenda la tarea de
      // las 14:00, pero el plugin (fake con reloj 15:00) lanza ArgumentError
      // al validar `fireTime` → la defensa por tarea debe continuar con el resto.
      scheduler.throwOnPastFireTime = true;
      scheduler.nowProvider = () => DateTime(2026, 1, 15, 15, 0);

      final tasks = [
        _task('a', DateTime(2026, 1, 15), scheduledTime: _atTwo),
        _task('b', DateTime(2026, 1, 16),
            scheduledTime: DateTime(2026, 1, 16, 9, 0)),
      ];
      await manager.syncAllTaskReminders(
          tasks, _settings(), now: DateTime(2026, 1, 15, 8, 0));

      expect(scheduler.scheduled.containsKey(reminderIdForTask('a')), isFalse,
          reason: 'la tarea que lanza no queda programada');
      expect(scheduler.scheduled.keys, contains(reminderIdForTask('b')),
          reason: 'el fallo de una tarea no aborta las demás');
    });

    test('cancelTaskReminder cancela un id concreto', () async {
      await manager.cancelTaskReminder('x');
      expect(scheduler.cancelled, contains(reminderIdForTask('x')));
    });
  });

  group('syncDailyReminders (P3/P5)', () {
    final pendingToday = [
      _task('a', DateTime(2026, 1, 15), scheduledTime: _atTwo),
      _task('b', DateTime(2026, 1, 15)),
    ];

    test('a las 08:00 con pendientes y nada completado: programa 10:00 y 19:00',
        () async {
      final now = DateTime(2026, 1, 15, 8, 0);
      await manager.syncDailyReminders(
          now: now, allTasks: pendingToday, settings: _settings());

      expect(
        scheduler.scheduled[morningDailyReminderId]!.fireTime,
        DateTime(2026, 1, 15, 10, 0),
      );
      expect(
        scheduler.scheduled[eveningDailyReminderId]!.fireTime,
        DateTime(2026, 1, 15, 19, 0),
      );
    });

    test('se completó algo HOY: la de las 19:00 NO se programa (P5)', () async {
      final now = DateTime(2026, 1, 15, 8, 0);
      final tasks = [
        ...pendingToday,
        _task('done', DateTime(2026, 1, 15),
            isCompleted: true, completedAt: DateTime(2026, 1, 15, 9, 0)),
      ];
      await manager.syncDailyReminders(
          now: now, allTasks: tasks, settings: _settings());

      expect(scheduler.scheduled.containsKey(morningDailyReminderId), isTrue);
      expect(scheduler.scheduled.containsKey(eveningDailyReminderId), isFalse);
      expect(scheduler.cancelled, contains(eveningDailyReminderId));
    });

    test('sin pendientes hoy: cancela ambos resúmenes', () async {
      final now = DateTime(2026, 1, 15, 8, 0);
      await manager.syncDailyReminders(
        now: now,
        allTasks: [_task('done', DateTime(2026, 1, 15), isCompleted: true)],
        settings: _settings(),
      );
      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.cancelled,
          containsAll([morningDailyReminderId, eveningDailyReminderId]));
    });

    test('las 10:00 pasadas: se cancela; las 19:00 aún se programa', () async {
      final now = DateTime(2026, 1, 15, 11, 0);
      await manager.syncDailyReminders(
          now: now, allTasks: pendingToday, settings: _settings());
      expect(scheduler.scheduled.containsKey(morningDailyReminderId), isFalse);
      expect(scheduler.cancelled, contains(morningDailyReminderId));
      expect(
        scheduler.scheduled[eveningDailyReminderId]!.fireTime,
        DateTime(2026, 1, 15, 19, 0),
      );
    });

    test('ambas horas pasadas: nada programado', () async {
      final now = DateTime(2026, 1, 15, 20, 0);
      await manager.syncDailyReminders(
          now: now, allTasks: pendingToday, settings: _settings());
      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.cancelled,
          containsAll([morningDailyReminderId, eveningDailyReminderId]));
    });

    test('resumen diario desactivado: cancela ambos', () async {
      final now = DateTime(2026, 1, 15, 8, 0);
      await manager.syncDailyReminders(
        now: now,
        allTasks: pendingToday,
        settings: const UserSettings(dailyReminderEnabled: false),
      );
      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.cancelled,
          containsAll([morningDailyReminderId, eveningDailyReminderId]));
    });

    test('notificaciones globales desactivadas: cancela ambos', () async {
      final now = DateTime(2026, 1, 15, 8, 0);
      await manager.syncDailyReminders(
        now: now,
        allTasks: pendingToday,
        settings: _settings(notificationsEnabled: false),
      );
      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.cancelled,
          containsAll([morningDailyReminderId, eveningDailyReminderId]));
    });

    test('horas configurables en Ajustes cambian el disparo', () async {
      final now = DateTime(2026, 1, 15, 6, 0);
      const settings =
          UserSettings(dailyReminderHour1: 8, dailyReminderHour2: 21);
      await manager.syncDailyReminders(
          now: now, allTasks: pendingToday, settings: settings);
      expect(
        scheduler.scheduled[morningDailyReminderId]!.fireTime,
        DateTime(2026, 1, 15, 8, 0),
      );
      expect(
        scheduler.scheduled[eveningDailyReminderId]!.fireTime,
        DateTime(2026, 1, 15, 21, 0),
      );
    });
  });

  group('cancelDailyReminders', () {
    test('cancela los dos ids del resumen diario', () async {
      await manager.cancelDailyReminders();
      expect(scheduler.cancelled,
          containsAll([morningDailyReminderId, eveningDailyReminderId]));
    });
  });

  group('syncDayClosure (decisión C: cierre de jornada)', () {
    test('después del reset: programa MAÑANA a las 04:00 reportando hoy',
        () async {
      final now = DateTime(2026, 1, 15, 10, 0);
      const settings = UserSettings(enableDayClosure: true);
      await manager.syncDayClosure(
          now: now, allTasks: tareasHoy, settings: settings);

      final entry = scheduler.scheduled[dayClosureReminderId];
      expect(entry, isNotNull);
      expect(entry!.fireTime, DateTime(2026, 1, 16, 4, 0));
      expect(entry.body, contains('1/2'));
    });

    test('antes del reset: programa HOY a las 04:00 reportando ayer', () async {
      final now = DateTime(2026, 1, 15, 3, 0);
      const settings = UserSettings(enableDayClosure: true);
      final tareasAyer =
          tareasHoy.map((t) => _task(t.id, DateTime(2026, 1, 14))).toList();
      await manager.syncDayClosure(
          now: now, allTasks: tareasAyer, settings: settings);

      final entry = scheduler.scheduled[dayClosureReminderId];
      expect(entry, isNotNull);
      expect(entry!.fireTime, DateTime(2026, 1, 15, 4, 0));
    });

    test('toggle off: cancela aunque haya tareas', () async {
      final now = DateTime(2026, 1, 15, 10, 0);
      await manager.syncDayClosure(
          now: now, allTasks: tareasHoy, settings: const UserSettings());

      expect(scheduler.scheduled.containsKey(dayClosureReminderId), isFalse);
      expect(scheduler.cancelled, contains(dayClosureReminderId));
    });

    test('borde: now == dayResetHour -> NO cierra HOY; programa MAÑANA '
        'reportando la jornada de hoy', () async {
      // A las 04:00 exactas (dayResetHour por defecto) el reset de HOY ya no
      // es estrictamente posterior a `now` (`nextDayReset` usa `isBefore`),
      // por lo que el comportamiento esperado es el de "no cerrar hoy,
      // preparar mañana": el cierre se agenda para MAÑANA a las 04:00 y
      // reporta la jornada de HOY (15/01).
      final now = DateTime(2026, 1, 15, 4, 0);
      const settings = UserSettings(enableDayClosure: true);
      await manager.syncDayClosure(
          now: now, allTasks: tareasHoy, settings: settings);

      final entry = scheduler.scheduled[dayClosureReminderId];
      expect(entry, isNotNull);
      expect(entry!.fireTime, DateTime(2026, 1, 16, 4, 0),
          reason: 'en la hora exacta del reset el próximo disparo es mañana');
      expect(entry.body, contains('1/2'),
          reason: 'reporta la jornada de hoy (1 completada de 2)');
    });

    test('sin tareas en la jornada y racha 0: cancela', () async {
      final now = DateTime(2026, 1, 15, 10, 0);
      const settings = UserSettings(enableDayClosure: true);
      await manager.syncDayClosure(
          now: now,
          allTasks: [_task('d', DateTime(2026, 1, 16))],
          settings: settings,
          currentStreak: 0);

      expect(scheduler.scheduled.containsKey(dayClosureReminderId), isFalse);
      expect(scheduler.cancelled, contains(dayClosureReminderId));
    });

    test('sin tareas pero racha > 0: programa igual (decisión C)', () async {
      final now = DateTime(2026, 1, 15, 10, 0);
      const settings = UserSettings(enableDayClosure: true);
      await manager.syncDayClosure(
          now: now,
          allTasks: [_task('d', DateTime(2026, 1, 16))],
          settings: settings,
          currentStreak: 30,
          milestone: BadgeType.streak30);

      final entry = scheduler.scheduled[dayClosureReminderId];
      expect(entry, isNotNull);
      expect(entry!.body, contains('Racha actual: 30 días'));
      expect(entry.body, contains('Hito desbloqueado: Mes de Hierro'));
    });
  });

  group('textos temáticos Slate System', () {
    test('con resolver: el recordatorio usa los textos del catálogo', () async {
      final themedManager = ReminderManager(
        scheduler: scheduler,
        resolver: const ThematicTextsResolver(),
      );
      final task = _task('t', DateTime(2026, 1, 15), scheduledTime: _atTwo);
      await themedManager.syncTaskReminder(
          task, _settings(), now: _earlyMorning);

      final entry = scheduler.scheduled[reminderIdForTask('t')]!;
      expect(entry.title, contains('Daily Quest'));
      expect(entry.body, contains('▶'));
      expect(entry.body, contains('14:00'));
    });

    test('con resolver: el cierre de jornada usa texto temático', () async {
      final manager = ReminderManager(
        scheduler: scheduler,
        resolver: const ThematicTextsResolver(),
      );
      const settings = UserSettings(enableDayClosure: true);
      await manager.syncDayClosure(
        now: DateTime(2026, 1, 15, 10, 0),
        allTasks: tareasHoy,
        settings: settings,
        currentStreak: 3,
        milestone: BadgeType.streak3,
      );

      final entry = scheduler.scheduled[dayClosureReminderId]!;
      expect(entry.title, contains('System Report'));
      expect(entry.body, contains('Jornada cerrada'));
    });
  });

  group('syncStreakAtRiskReminder (F2, decisión B: alerta de racha)', () {
    // Día con tareas pendientes pero NINGUNA completada todavía.
    final sinCompletarHoy = [_task('a', DateTime(2026, 1, 15))];
    final now = DateTime(2026, 1, 15, 8, 0); // antes de las 12:00

    test('dispara a las 12:00 del mediodía con racha ≥3 y sin completados hoy',
        () async {
      await manager.syncStreakAtRiskReminder(
        now: now,
        allTasks: sinCompletarHoy,
        settings: _settings(),
        currentStreak: 3,
      );

      final entry = scheduler.scheduled[streakAtRiskReminderId];
      expect(entry, isNotNull);
      expect(
        entry!.fireTime,
        DateTime(2026, 1, 15, 12, 0),
        reason: 'la alerta se fija a las 12:00 del MEDIODÍA (12 PM), '
            'nunca a medianoche',
      );
      expect(entry.body,
          'Tu racha de 3 días se perderá si no completas una misión hoy.');
    });

    test('el id es 0x60000004 (libre; tareas usan 0x10000000-0x4FFFFFFF',
        () async {
      await manager.syncStreakAtRiskReminder(
        now: now,
        allTasks: sinCompletarHoy,
        settings: _settings(),
        currentStreak: 7,
      );
      expect(scheduler.scheduled.containsKey(streakAtRiskReminderId), isTrue);
      expect(streakAtRiskReminderId, 0x60000004);
    });

    test('no dispara si ya se completó la primera tarea del día', () async {
      final tasks = [
        ...sinCompletarHoy,
        _task('done', DateTime(2026, 1, 15),
            isCompleted: true, completedAt: DateTime(2026, 1, 15, 9, 0)),
      ];
      await manager.syncStreakAtRiskReminder(
        now: DateTime(2026, 1, 15, 8, 0),
        allTasks: tasks,
        settings: _settings(),
        currentStreak: 5,
      );

      expect(scheduler.scheduled.containsKey(streakAtRiskReminderId), isFalse);
      expect(scheduler.cancelled, contains(streakAtRiskReminderId));
    });

    test('no dispara si la racha es menor que 3', () async {
      await manager.syncStreakAtRiskReminder(
        now: now,
        allTasks: sinCompletarHoy,
        settings: _settings(),
        currentStreak: 2,
      );

      expect(scheduler.scheduled.containsKey(streakAtRiskReminderId), isFalse);
      expect(scheduler.cancelled, contains(streakAtRiskReminderId));
    });

    test('cancelación: la hora (12:00) ya pasó → nunca programa al pasado',
        () async {
      await manager.syncStreakAtRiskReminder(
        now: DateTime(2026, 1, 15, 13, 0),
        allTasks: sinCompletarHoy,
        settings: _settings(),
        currentStreak: 10,
      );

      expect(scheduler.scheduled.containsKey(streakAtRiskReminderId), isFalse);
      expect(scheduler.cancelled, contains(streakAtRiskReminderId));
    });

    test('cancelación: notificaciones desactivadas', () async {
      await manager.syncStreakAtRiskReminder(
        now: now,
        allTasks: sinCompletarHoy,
        settings: _settings(notificationsEnabled: false),
        currentStreak: 6,
      );

      expect(scheduler.scheduled.containsKey(streakAtRiskReminderId), isFalse);
      expect(scheduler.cancelled, contains(streakAtRiskReminderId));
    });

    test('con resolver: usa el texto temático "⚠ Racha en peligro"', () async {
      final themedManager = ReminderManager(
        scheduler: scheduler,
        resolver: const ThematicTextsResolver(),
      );
      await themedManager.syncStreakAtRiskReminder(
        now: now,
        allTasks: sinCompletarHoy,
        settings: _settings(),
        currentStreak: 7,
      );

      final entry = scheduler.scheduled[streakAtRiskReminderId]!;
      expect(entry.title, contains('⚠'));
      expect(entry.title, contains('Racha en peligro'));
      expect(entry.body, contains('Tu racha de 7 días'));
    });
  });

  group('syncFortnightSummary (F3, decisión D: resumen quincenal)', () {
    const hour = fortnightSummaryReminderHour;

    Badge badge(String id, DateTime unlockedAt) => Badge(
          id: id,
          type: BadgeType.streak3,
          name: 'n',
          iconName: 'i',
          unlockedAt: unlockedAt,
        );

    test('día 5 → programa el día 16 a las 20:00 (reporta 1..15 del mes)',
        () async {
      final now = DateTime(2026, 8, 5, 8, 0);
      final tasks = [
        _task('a', DateTime(2026, 8, 2),
            isCompleted: true, completedAt: DateTime(2026, 8, 2, 9, 0)),
        _task('b', DateTime(2026, 8, 14),
            isCompleted: true, completedAt: DateTime(2026, 8, 14, 10, 0)),
        // Fuera del periodo reportado (quincena-1): se completa el 16.
        _task('c', DateTime(2026, 8, 16),
            isCompleted: true, completedAt: DateTime(2026, 8, 16, 11, 0)),
      ];
      await manager.syncFortnightSummary(
        now: now,
        allTasks: tasks,
        settings: _settings(),
        currentStreak: 4,
        level: 2,
        totalXp: 120,
        badges: [badge('b1', DateTime(2026, 8, 10))],
      );

      final entry = scheduler.scheduled[fortnightSummaryReminderId];
      expect(entry, isNotNull);
      expect(entry!.fireTime, DateTime(2026, 8, 16, hour, 0));
      // Reporta la quincena-1: solo "a" y "b" (2), no "c".
      expect(entry.body, contains('01/08 - 15/08'));
      expect(entry.body, contains('2 tareas completadas'));
      expect(entry.body, contains('Racha actual: 4 días'));
      expect(entry.body, contains('Nivel 2 · 120 XP'));
      expect(entry.body, contains('Insignias desbloqueadas: 1'));
    });

    test('día 1 a las 08:00 → programa HOY a las 20:00 reportando la '
        'quincena-2 del mes ANTERIOR', () async {
      final now = DateTime(2026, 9, 1, 8, 0);
      final tasks = [
        _task('a', DateTime(2026, 9, 1)), // pendiente, no cuenta
        _task('b', DateTime(2026, 8, 20),
            isCompleted: true, completedAt: DateTime(2026, 8, 20, 9, 0)),
        _task('c', DateTime(2026, 8, 30),
            isCompleted: true, completedAt: DateTime(2026, 8, 30, 10, 0)),
      ];
      await manager.syncFortnightSummary(
        now: now,
        allTasks: tasks,
        settings: _settings(),
        currentStreak: 10,
        level: 3,
        totalXp: 400,
        badges: [],
      );

      final entry = scheduler.scheduled[fortnightSummaryReminderId];
      expect(entry, isNotNull);
      expect(entry!.fireTime, DateTime(2026, 9, 1, hour, 0));
      // Reporta la quincena-2 de AGOSTO (16..31): "b" y "c" (2).
      expect(entry.body, contains('16/08 - 31/08'));
      expect(entry.body, contains('2 tareas completadas'));
    });

    test('día 16 después de las 20:00 → programa el 1 del mes siguiente',
        () async {
      final now = DateTime(2026, 8, 16, 21, 0);
      await manager.syncFortnightSummary(
        now: now,
        allTasks: [],
        settings: _settings(),
        currentStreak: 0,
        level: 1,
        totalXp: 0,
        badges: [],
      );

      final entry = scheduler.scheduled[fortnightSummaryReminderId];
      expect(entry, isNotNull);
      expect(entry!.fireTime, DateTime(2026, 9, 1, hour, 0));
    });

    test('el id es 0x60000005 (libre; tareas usan 0x10000000-0x4FFFFFFF',
        () async {
      expect(fortnightSummaryReminderId, 0x60000005);
      await manager.syncFortnightSummary(
        now: DateTime(2026, 8, 5, 8, 0),
        allTasks: [],
        settings: _settings(),
        currentStreak: 0,
        level: 1,
        totalXp: 0,
        badges: [],
      );
      expect(
        scheduler.scheduled.containsKey(fortnightSummaryReminderId),
        isTrue,
      );
    });

    test('cancelación: notificaciones desactivadas', () async {
      await manager.syncFortnightSummary(
        now: DateTime(2026, 8, 5, 8, 0),
        allTasks: [_task('a', DateTime(2026, 8, 5))],
        settings: _settings(notificationsEnabled: false),
        currentStreak: 3,
        level: 1,
        totalXp: 0,
        badges: [],
      );

      expect(
        scheduler.scheduled.containsKey(fortnightSummaryReminderId),
        isFalse,
      );
      expect(scheduler.cancelled, contains(fortnightSummaryReminderId));
    });

    test('con resolver: usa el texto temático "◇ System Report — Quincena"',
        () async {
      final themedManager = ReminderManager(
        scheduler: scheduler,
        resolver: const ThematicTextsResolver(),
      );
      await themedManager.syncFortnightSummary(
        now: DateTime(2026, 8, 5, 8, 0),
        allTasks: [_task('a', DateTime(2026, 8, 2))],
        settings: _settings(),
        currentStreak: 2,
        level: 1,
        totalXp: 10,
        badges: [],
      );

      final entry = scheduler.scheduled[fortnightSummaryReminderId]!;
      expect(entry.title, contains('◇'));
      expect(entry.title, contains('System Report — Quincena'));
      expect(entry.body, contains('Quincena 01/08 - 15/08'));
    });
  });
}
