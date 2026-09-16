import 'package:flutter_test/flutter_test.dart';

import 'package:slate_app/application/services/task_schedule_calculator.dart';
import 'package:slate_app/domain/entities/task.dart';
import 'package:slate_app/domain/enums/recurrence_type.dart';

Task _task({
  required DateTime scheduledDate,
  DateTime? scheduledTime,
  int? durationMinutes,
  String? parentTaskId,
  RecurrenceType recurrence = RecurrenceType.none,
}) {
  return Task(
    id: 't1',
    title: 'Tarea',
    scheduledDate: scheduledDate,
    scheduledTime: scheduledTime,
    durationMinutes: durationMinutes,
    parentTaskId: parentTaskId,
    recurrence: recurrence,
    createdAt: scheduledDate,
  );
}

void main() {
  group('TaskScheduleCalculator - sin horario', () {
    test('effectiveStart/effectiveEnd/effectiveRange son null sin scheduledTime', () {
      final task = _task(scheduledDate: DateTime(2026, 3, 10));

      expect(TaskScheduleCalculator.effectiveStart(task), isNull);
      expect(TaskScheduleCalculator.effectiveEnd(task), isNull);
      expect(TaskScheduleCalculator.effectiveRange(task), isNull);
    });
  });

  group('TaskScheduleCalculator - legacy sin duración', () {
    test('con scheduledTime pero durationMinutes null, effectiveEnd/Range son null', () {
      final task = _task(
        scheduledDate: DateTime(2026, 3, 10),
        scheduledTime: DateTime(2026, 3, 10, 14, 30),
      );

      expect(TaskScheduleCalculator.effectiveStart(task), DateTime(2026, 3, 10, 14, 30));
      expect(TaskScheduleCalculator.effectiveEnd(task), isNull);
      expect(TaskScheduleCalculator.effectiveRange(task), isNull);
    });

    test('durationMinutes == 0 también se trata como legacy sin fin', () {
      final task = _task(
        scheduledDate: DateTime(2026, 3, 10),
        scheduledTime: DateTime(2026, 3, 10, 9, 0),
        durationMinutes: 0,
      );

      expect(TaskScheduleCalculator.effectiveEnd(task), isNull);
    });
  });

  group('TaskScheduleCalculator - rango normal', () {
    test('effectiveEnd = effectiveStart + duración', () {
      final task = _task(
        scheduledDate: DateTime(2026, 3, 10),
        scheduledTime: DateTime(2026, 3, 10, 14, 30),
        durationMinutes: 90,
      );

      final range = TaskScheduleCalculator.effectiveRange(task);
      expect(range, isNotNull);
      expect(range!.start, DateTime(2026, 3, 10, 14, 30));
      expect(range.end, DateTime(2026, 3, 10, 16, 0));
    });
  });

  group('TaskScheduleCalculator - cruce de medianoche', () {
    test('23:30 + 60 min termina a las 00:30 del día siguiente', () {
      final task = _task(
        scheduledDate: DateTime(2026, 3, 10),
        scheduledTime: DateTime(2026, 3, 10, 23, 30),
        durationMinutes: 60,
      );

      final range = TaskScheduleCalculator.effectiveRange(task);
      expect(range!.start, DateTime(2026, 3, 10, 23, 30));
      expect(range.end, DateTime(2026, 3, 11, 0, 30));
    });
  });

  group('TaskScheduleCalculator - ocurrencia recurrente', () {
    test('usa el día de scheduledDate, NO el día que arrastra scheduledTime', () {
      // Trampa documentada (A8/A11): en una ocurrencia recurrente,
      // scheduledTime conserva el día de la tarea RAÍZ (aquí 1 de marzo),
      // mientras que scheduledDate ya avanzó al día real de la ocurrencia
      // (10 de marzo). El día autoritativo es siempre scheduledDate.
      final occurrence = _task(
        scheduledDate: DateTime(2026, 3, 10),
        scheduledTime: DateTime(2026, 3, 1, 9, 0),
        durationMinutes: 30,
        parentTaskId: 'root',
      );

      final range = TaskScheduleCalculator.effectiveRange(occurrence);
      expect(range!.start, DateTime(2026, 3, 10, 9, 0),
          reason: 'el día debe ser el de scheduledDate, no el de scheduledTime');
      expect(range.end, DateTime(2026, 3, 10, 9, 30));
    });
  });
}
