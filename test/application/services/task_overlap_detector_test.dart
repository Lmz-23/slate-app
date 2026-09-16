import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';

import 'package:slate_app/application/services/task_overlap_detector.dart';
import 'package:slate_app/domain/entities/task.dart';
import 'package:slate_app/domain/enums/recurrence_type.dart';

Task _task({
  required String id,
  required DateTime scheduledDate,
  DateTime? scheduledTime,
  int? durationMinutes,
  bool isCompleted = false,
  bool isSubtask = false,
  String? parentTaskId,
  String title = 'Tarea',
}) {
  return Task(
    id: id,
    title: title,
    scheduledDate: scheduledDate,
    scheduledTime: scheduledTime,
    durationMinutes: durationMinutes,
    isCompleted: isCompleted,
    isSubtask: isSubtask,
    parentTaskId: parentTaskId,
    createdAt: scheduledDate,
  );
}

TaskDraftSchedule _draft({
  required DateTime scheduledDate,
  required TimeOfDay startTime,
  required int durationMinutes,
  RecurrenceType recurrence = RecurrenceType.none,
  List<int>? recurrenceDays,
}) {
  return TaskDraftSchedule(
    scheduledDate: scheduledDate,
    startTime: startTime,
    durationMinutes: durationMinutes,
    recurrence: recurrence,
    recurrenceDays: recurrenceDays,
  );
}

void main() {
  final day = DateTime(2026, 3, 10);

  group('TaskOverlapDetector - solapamiento simple', () {
    test('detecta conflicto cuando los rangos se cruzan', () {
      final existing = _task(
        id: 'a',
        scheduledDate: day,
        scheduledTime: DateTime(2026, 3, 10, 14, 0),
        durationMinutes: 60,
        title: 'Reunión',
      );
      final detector = TaskOverlapDetector([existing]);

      final conflict = detector.findFirstConflict(
        _draft(scheduledDate: day, startTime: const TimeOfDay(hour: 14, minute: 30), durationMinutes: 60),
      );

      expect(conflict, isNotNull);
      expect(conflict!.taskId, 'a');
      expect(conflict.title, 'Reunión');
    });

    test('NO detecta conflicto con rangos adyacentes (semiabierto [start, end))', () {
      final existing = _task(
        id: 'a',
        scheduledDate: day,
        scheduledTime: DateTime(2026, 3, 10, 13, 0),
        durationMinutes: 60, // 13:00-14:00
      );
      final detector = TaskOverlapDetector([existing]);

      final conflict = detector.findFirstConflict(
        _draft(scheduledDate: day, startTime: const TimeOfDay(hour: 14, minute: 0), durationMinutes: 60),
      );

      expect(conflict, isNull);
    });

    test('NO detecta conflicto cuando no hay solapamiento real', () {
      final existing = _task(
        id: 'a',
        scheduledDate: day,
        scheduledTime: DateTime(2026, 3, 10, 9, 0),
        durationMinutes: 30,
      );
      final detector = TaskOverlapDetector([existing]);

      final conflict = detector.findFirstConflict(
        _draft(scheduledDate: day, startTime: const TimeOfDay(hour: 18, minute: 0), durationMinutes: 30),
      );

      expect(conflict, isNull);
    });
  });

  group('TaskOverlapDetector - exclusiones', () {
    test('excluye tareas sin horario', () {
      final noTime = _task(id: 'a', scheduledDate: day);
      final detector = TaskOverlapDetector([noTime]);

      final conflict = detector.findFirstConflict(
        _draft(scheduledDate: day, startTime: const TimeOfDay(hour: 10, minute: 0), durationMinutes: 60),
      );

      expect(conflict, isNull);
    });

    test('excluye subtareas', () {
      final subtask = _task(
        id: 'sub',
        scheduledDate: day,
        scheduledTime: DateTime(2026, 3, 10, 10, 0),
        durationMinutes: 60,
        isSubtask: true,
        parentTaskId: 'root',
      );
      final detector = TaskOverlapDetector([subtask]);

      final conflict = detector.findFirstConflict(
        _draft(scheduledDate: day, startTime: const TimeOfDay(hour: 10, minute: 0), durationMinutes: 60),
      );

      expect(conflict, isNull);
    });

    test('excluye tareas legacy sin durationMinutes conocido', () {
      final legacy = _task(
        id: 'legacy',
        scheduledDate: day,
        scheduledTime: DateTime(2026, 3, 10, 10, 0),
      );
      final detector = TaskOverlapDetector([legacy]);

      final conflict = detector.findFirstConflict(
        _draft(scheduledDate: day, startTime: const TimeOfDay(hour: 10, minute: 0), durationMinutes: 60),
      );

      expect(conflict, isNull);
    });

    test('excluye tareas completadas', () {
      final completed = _task(
        id: 'done',
        scheduledDate: day,
        scheduledTime: DateTime(2026, 3, 10, 10, 0),
        durationMinutes: 60,
        isCompleted: true,
      );
      final detector = TaskOverlapDetector([completed]);

      final conflict = detector.findFirstConflict(
        _draft(scheduledDate: day, startTime: const TimeOfDay(hour: 10, minute: 0), durationMinutes: 60),
      );

      expect(conflict, isNull);
    });

    test('excluye la propia tarea en edición y toda su serie', () {
      final root = _task(
        id: 'root',
        scheduledDate: day,
        scheduledTime: DateTime(2026, 3, 10, 10, 0),
        durationMinutes: 60,
      );
      final child = _task(
        id: 'child',
        scheduledDate: day.add(const Duration(days: 1)),
        scheduledTime: DateTime(2026, 3, 10, 10, 0),
        durationMinutes: 60,
        parentTaskId: 'root',
      );
      final detector = TaskOverlapDetector([root, child]);

      // Editando la RAÍZ: no debe conflictuar con la hija de su propia serie.
      final conflict = detector.findFirstConflict(
        _draft(scheduledDate: day, startTime: const TimeOfDay(hour: 10, minute: 0), durationMinutes: 60),
        editingTaskId: 'root',
      );

      expect(conflict, isNull);
    });
  });

  group('TaskOverlapDetector - recurrencia', () {
    test('proyecta ocurrencias diarias del borrador y detecta conflicto futuro', () {
      final existingFuture = _task(
        id: 'future',
        scheduledDate: day.add(const Duration(days: 3)),
        scheduledTime: DateTime(2026, 3, 10, 9, 0),
        durationMinutes: 60,
      );
      final detector = TaskOverlapDetector([existingFuture]);

      final conflict = detector.findFirstConflict(
        _draft(
          scheduledDate: day,
          startTime: const TimeOfDay(hour: 9, minute: 0),
          durationMinutes: 60,
          recurrence: RecurrenceType.daily,
        ),
      );

      expect(conflict, isNotNull);
      expect(conflict!.taskId, 'future');
      expect(conflict.isRecurringOccurrence, isFalse);
    });

    test('reporta el PRIMER conflicto cronológico entre varias ocurrencias', () {
      final laterConflict = _task(
        id: 'later',
        scheduledDate: day.add(const Duration(days: 5)),
        scheduledTime: DateTime(2026, 3, 10, 9, 0),
        durationMinutes: 60,
      );
      final earlierConflict = _task(
        id: 'earlier',
        scheduledDate: day.add(const Duration(days: 2)),
        scheduledTime: DateTime(2026, 3, 10, 9, 0),
        durationMinutes: 60,
      );
      final detector = TaskOverlapDetector([laterConflict, earlierConflict]);

      final conflict = detector.findFirstConflict(
        _draft(
          scheduledDate: day,
          startTime: const TimeOfDay(hour: 9, minute: 0),
          durationMinutes: 60,
          recurrence: RecurrenceType.daily,
        ),
      );

      expect(conflict!.taskId, 'earlier');
    });
  });

  group('TaskOverlapDetector - A14 (truncar)', () {
    test('canTruncate es true cuando la tarea existente empieza ANTES que el borrador', () {
      final existing = _task(
        id: 'a',
        scheduledDate: day,
        scheduledTime: DateTime(2026, 3, 10, 14, 0),
        durationMinutes: 90, // 14:00-15:30
      );
      final detector = TaskOverlapDetector([existing]);

      final conflict = detector.findFirstConflict(
        _draft(scheduledDate: day, startTime: const TimeOfDay(hour: 14, minute: 30), durationMinutes: 30),
      );

      expect(conflict!.canTruncate, isTrue);
      // Duración resultante: minutos del borrador (14:30) - minutos de la
      // existente (14:00) = 30.
      expect(conflict.truncatedDurationMinutes, 30);
    });

    test('canTruncate es false cuando la existente empieza a la vez o después', () {
      final existing = _task(
        id: 'a',
        scheduledDate: day,
        scheduledTime: DateTime(2026, 3, 10, 15, 0),
        durationMinutes: 60,
      );
      final detector = TaskOverlapDetector([existing]);

      final conflict = detector.findFirstConflict(
        _draft(scheduledDate: day, startTime: const TimeOfDay(hour: 14, minute: 30), durationMinutes: 60),
      );

      expect(conflict!.canTruncate, isFalse);
      expect(conflict.truncatedDurationMinutes, isNull);
    });
  });
}
