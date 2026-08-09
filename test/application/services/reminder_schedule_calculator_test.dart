import 'package:flutter_test/flutter_test.dart';

import 'package:slate_app/application/services/reminder_schedule_calculator.dart';
import 'package:slate_app/domain/entities/task.dart';
import 'package:slate_app/domain/enums/badge_type.dart';

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

void main() {
  group('effectiveDateTime', () {
    test('combina la fecha programada con la hora del scheduledTime', () {
      final task = _task(
        'a',
        DateTime(2026, 1, 2),
        scheduledTime: DateTime(2026, 1, 1, 14, 30),
      );
      expect(
        ReminderScheduleCalculator.effectiveDateTime(task),
        DateTime(2026, 1, 2, 14, 30),
      );
    });

    test(
        'ocurrecia recurrente usa el DÍA de scheduledDate (no el de scheduledTime)',
        () {
      // Simula una hija de serie generada: scheduledDate avanza pero
      // scheduledTime conserva el día original del padre.
      final occurrence = _task(
        'child',
        DateTime(2026, 1, 16),
        scheduledTime: DateTime(2026, 1, 1, 8, 0),
      );
      expect(
        ReminderScheduleCalculator.effectiveDateTime(occurrence),
        DateTime(2026, 1, 16, 8, 0),
      );
    });

    test('sin horario devuelve la fecha programada', () {
      final task = _task('a', DateTime(2026, 1, 2));
      expect(
        ReminderScheduleCalculator.effectiveDateTime(task),
        DateTime(2026, 1, 2, 0, 0),
      );
    });
  });

  group('taskReminderFireTime (margen P2)', () {
    final task = _task(
      'a',
      DateTime(2026, 1, 15),
      scheduledTime: DateTime(2026, 1, 15, 14, 0),
    );

    test('margen 0 (default): aviso justo a la hora de la tarea', () {
      expect(
        ReminderScheduleCalculator.taskReminderFireTime(task, 0),
        DateTime(2026, 1, 15, 14, 0),
      );
    });

    test('margen positivo adelanta el aviso', () {
      expect(
        ReminderScheduleCalculator.taskReminderFireTime(task, 15),
        DateTime(2026, 1, 15, 13, 45),
      );
      expect(
        ReminderScheduleCalculator.taskReminderFireTime(task, 60),
        DateTime(2026, 1, 15, 13, 0),
      );
    });
  });

  group('nextDailyReminderTime', () {
    test('hora futura hoy -> misma día', () {
      final now = DateTime(2026, 1, 15, 8, 0);
      expect(
        ReminderScheduleCalculator.nextDailyReminderTime(now, 10),
        DateTime(2026, 1, 15, 10, 0),
      );
    });

    test('hora pasada -> mañana', () {
      final now = DateTime(2026, 1, 15, 11, 0);
      expect(
        ReminderScheduleCalculator.nextDailyReminderTime(now, 10),
        DateTime(2026, 1, 16, 10, 0),
      );
    });

    test('hora exacta actual -> siguiente día (debe ser estrictamente futura)',
        () {
      final now = DateTime(2026, 1, 15, 10, 0);
      expect(
        ReminderScheduleCalculator.nextDailyReminderTime(now, 10),
        DateTime(2026, 1, 16, 10, 0),
      );
    });

    test('fuerza minutos a 0', () {
      final now = DateTime(2026, 1, 15, 7, 45);
      expect(
        ReminderScheduleCalculator.nextDailyReminderTime(now, 10),
        DateTime(2026, 1, 15, 10, 0),
      );
    });
  });

  group('pending/confirmed del día', () {
    final day = DateTime(2026, 1, 15);

    test('hasPendingTasksOn true con pendiente', () {
      expect(
        ReminderScheduleCalculator.hasPendingTasksOn([
          _task('a', day),
          _task('b', day, isCompleted: true),
        ], day),
        isTrue,
      );
    });

    test('hasPendingTasksOn false si todas completadas', () {
      expect(
        ReminderScheduleCalculator.hasPendingTasksOn(
          [_task('a', day, isCompleted: true)],
          day,
        ),
        isFalse,
      );
    });

    test('hasPendingTasksOn ignora tareas de otros días', () {
      expect(
        ReminderScheduleCalculator.hasPendingTasksOn(
          [
            _task('a', DateTime(2026, 1, 14)),
            _task('b', day, isCompleted: true)
          ],
          day,
        ),
        isFalse,
      );
    });

    test('pendingCountOn cuenta solo las pendientes del día', () {
      final tasks = [
        _task('a', day),
        _task('b', day),
        _task('c', day, isCompleted: true),
        _task('d', DateTime(2026, 1, 16)),
      ];
      expect(ReminderScheduleCalculator.pendingCountOn(tasks, day), 2);
    });

    test('noTasksCompletedOn: false si hubo un completedAt hoy', () {
      final completedToday = _task(
        'a',
        day,
        isCompleted: true,
        completedAt: DateTime(2026, 1, 15, 9, 0),
      );
      expect(
        ReminderScheduleCalculator.noTasksCompletedOn([completedToday], day),
        isFalse,
      );
    });

    test('noTasksCompletedOn: true si el completedAt es OTRO día', () {
      final completedYesterday = _task(
        'a',
        day,
        isCompleted: true,
        completedAt: DateTime(2026, 1, 14, 23, 59),
      );
      expect(
        ReminderScheduleCalculator.noTasksCompletedOn(
            [completedYesterday], day),
        isTrue,
      );
    });
  });

  group('condiciones del resumen diario (P3/P5)', () {
    final day = DateTime(2026, 1, 15);

    test('10:00 -> true solo con pendientes hoy', () {
      expect(
        ReminderScheduleCalculator.shouldFireMorningReminder(
          allTasks: [_task('a', day)],
          day: day,
        ),
        isTrue,
      );
      expect(
        ReminderScheduleCalculator.shouldFireMorningReminder(
          allTasks: [_task('a', day, isCompleted: true)],
          day: day,
        ),
        isFalse,
      );
    });

    test('19:00 -> verdadero con pendientes y sin completadas hoy', () {
      expect(
        ReminderScheduleCalculator.shouldFireEveningReminder(
          allTasks: [_task('a', day), _task('b', day)],
          day: day,
        ),
        isTrue,
      );
    });

    test('19:00 -> falso si no hay pendientes', () {
      expect(
        ReminderScheduleCalculator.shouldFireEveningReminder(
          allTasks: [_task('a', day, isCompleted: true)],
          day: day,
        ),
        isFalse,
      );
    });

    test('19:00 -> falso si se completó algo HOY (condición temporal)', () {
      final tasks = [
        _task('a', day),
        _task('done', day,
            isCompleted: true, completedAt: DateTime(2026, 1, 15, 12, 0)),
      ];
      expect(
        ReminderScheduleCalculator.shouldFireEveningReminder(
          allTasks: tasks,
          day: day,
        ),
        isFalse,
      );
    });

    test('pendientes + completadas ayer -> 19:00 sigue siendo válido', () {
      final tasks = [
        _task('a', day),
        _task('done-some-other-day', day,
            isCompleted: true, completedAt: DateTime(2026, 1, 14, 23, 59)),
      ];
      expect(
        ReminderScheduleCalculator.shouldFireEveningReminder(
          allTasks: tasks,
          day: day,
        ),
        isTrue,
      );
    });
  });

  group('contenido de las notificaciones', () {
    test('cuerpo del recordatorio de tarea incluye título y hora', () {
      final task = _task(
        'a',
        DateTime(2026, 1, 15),
        scheduledTime: DateTime(2026, 1, 15, 14, 0),
      );
      expect(
        ReminderScheduleCalculator.taskReminderBody(task),
        'Recordatorio: "Tarea a" a las 14:00',
      );
    });

    test('singular/plural del resumen de la mañana', () {
      expect(
        ReminderScheduleCalculator.morningReminderBody(1),
        'Tienes 1 tarea pendiente para hoy.',
      );
      expect(
        ReminderScheduleCalculator.morningReminderBody(3),
        'Tienes 3 tareas pendientes para hoy.',
      );
    });

    test('cuerpo del resumen de la tarde', () {
      expect(
        ReminderScheduleCalculator.eveningReminderBody(2),
        'Hoy no has completado ninguna tarea. Te quedan 2 pendientes.',
      );
    });
  });

  group('cierre de jornada (decisión C)', () {
    test('nextDayReset: antes del reset -> HOY; en/después -> MAÑANA', () {
      expect(
        ReminderScheduleCalculator.nextDayReset(DateTime(2026, 1, 15, 3, 0), 4),
        DateTime(2026, 1, 15, 4, 0),
      );
      expect(
        ReminderScheduleCalculator.nextDayReset(DateTime(2026, 1, 15, 4, 0), 4),
        DateTime(2026, 1, 16, 4, 0),
        reason: 'en el instante exacto del reset ya no se programa al pasado',
      );
      expect(
        ReminderScheduleCalculator.nextDayReset(DateTime(2026, 1, 15, 10, 0), 4),
        DateTime(2026, 1, 16, 4, 0),
      );
    });

    test('jornadaEndingAtNextReset: ayer si aún no pasó el reset; hoy si pasó',
        () {
      expect(
        ReminderScheduleCalculator.jornadaEndingAtNextReset(
            DateTime(2026, 1, 15, 3, 0), 4),
        DateTime(2026, 1, 14),
      );
      expect(
        ReminderScheduleCalculator.jornadaEndingAtNextReset(
            DateTime(2026, 1, 15, 10, 0), 4),
        DateTime(2026, 1, 15),
      );
    });

    test('hasTasksOn / scheduledCountOn / completedCountOn del día', () {
      final day = DateTime(2026, 1, 15);
      final tasks = [
        _task('a', day, isCompleted: true),
        _task('b', day),
        _task('c', day, isCompleted: true),
        _task('d', DateTime(2026, 1, 16)),
      ];
      expect(ReminderScheduleCalculator.hasTasksOn(tasks, day), isTrue);
      expect(ReminderScheduleCalculator.scheduledCountOn(tasks, day), 3);
      expect(ReminderScheduleCalculator.completedCountOn(tasks, day), 2);
      expect(
        ReminderScheduleCalculator.hasTasksOn(
            [_task('d', DateTime(2026, 1, 16))], day),
        isFalse,
      );
    });

    test('cuerpo canónico del cierre: completadas/total + pendientes', () {
      final stats = DayClosureStats(
        jornada: DateTime(2026, 1, 14),
        total: 5,
        completed: 3,
        currentStreak: 7,
      );
      final body = ReminderScheduleCalculator.dayClosureBody(stats);
      expect(body, contains('3/5'));
      expect(body, contains('2 pendientes'));
      expect(body, contains('Racha actual: 7 días'));
    });

    test('cuerpo canónico incluye el hito desbloqueado si existe', () {
      final day = DateTime(2026, 1, 14);
      final body = ReminderScheduleCalculator.dayClosureBody(
        DayClosureStats(
          jornada: day,
          total: 1,
          completed: 1,
          currentStreak: 3,
          milestone: BadgeType.streak3,
        ),
      );
      expect(body, contains('Hito desbloqueado: Primer Paso'));
    });
  });
}
