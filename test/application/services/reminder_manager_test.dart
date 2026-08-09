import 'package:flutter_test/flutter_test.dart';

import 'package:slate_app/application/services/notification_ids.dart';
import 'package:slate_app/application/services/reminder_manager.dart';
import 'package:slate_app/application/services/reminder_schedule_calculator.dart';
import 'package:slate_app/application/services/reminder_scheduler.dart';
import 'package:slate_app/domain/entities/task.dart';
import 'package:slate_app/domain/entities/user_settings.dart';

/// Fake del Contrato de bajo nivel: registra programaciones y cancelaciones sin
/// depender del plugin nativo.
class FakeScheduler implements ReminderScheduler {
  final scheduled = <int, ({DateTime fireTime, String title, String body})>{};
  final cancelled = <int>[];

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

void main() {
  late FakeScheduler scheduler;
  late ReminderManager manager;

  setUp(() {
    scheduler = FakeScheduler();
    manager = ReminderManager(scheduler: scheduler);
  });

  group('syncTaskReminder (P2)', () {
    test('programa solo si hay horario y notificaciones activas', () async {
      final task = _task('a', DateTime(2026, 1, 15), scheduledTime: _atTwo);
      await manager.syncTaskReminder(task, _settings());

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
      await manager.syncTaskReminder(task, _settings(lead: 15));

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
      await manager.syncTaskReminder(occurrence, _settings());
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
      await manager.syncTaskReminder(task, _settings());
      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.cancelled, contains(reminderIdForTask('t')));
    });

    test('tarea sin horario -> CANCELA', () async {
      final task = _task('t', DateTime(2026, 1, 15));
      await manager.syncTaskReminder(task, _settings());
      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.cancelled, contains(reminderIdForTask('t')));
    });

    test('notificaciones desactivadas -> CANCELA aunque tenga horario',
        () async {
      final task = _task('t', DateTime(2026, 1, 15), scheduledTime: _atTwo);
      await manager.syncTaskReminder(
          task, _settings(notificationsEnabled: false));
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
      await manager.syncAllTaskReminders(tasks, _settings());
      expect(scheduler.scheduled.keys, {
        reminderIdForTask('a'),
        reminderIdForTask('b'),
      });
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
}
