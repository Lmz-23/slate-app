import 'package:flutter_test/flutter_test.dart';

import 'package:slate_app/application/services/quest_calculator.dart';
import 'package:slate_app/domain/entities/task.dart';

Task _task(
  String id,
  DateTime scheduledDate, {
  bool isCompleted = false,
  DateTime? completedAt,
  bool isSubtask = false,
  String? parentTaskId,
}) {
  return Task(
    id: id,
    title: 'Tarea $id',
    scheduledDate: scheduledDate,
    isCompleted: isCompleted,
    completedAt: completedAt,
    createdAt: scheduledDate,
    parentTaskId: parentTaskId,
    isSubtask: isSubtask,
  );
}

void main() {
  final day = DateTime(2026, 8, 10);

  group('QuestCalculator.shouldBeVisible (decisión C)', () {
    test('oculta con <3 tareas programadas para hoy', () {
      final tasks = [_task('a', day), _task('b', day)];
      expect(QuestCalculator.shouldBeVisible(tasks, day), isFalse);
    });

    test('visible con EXACTAMENTE 3 tareas programadas', () {
      final tasks = [_task('a', day), _task('b', day), _task('c', day)];
      expect(QuestCalculator.shouldBeVisible(tasks, day), isTrue);
    });

    test('visible con más de 3 tareas (pendientes o ya completadas)', () {
      final tasks = [
        _task('a', day, isCompleted: true, completedAt: day.add(const Duration(hours: 1))),
        _task('b', day),
        _task('c', day),
        _task('d', day),
      ];
      expect(QuestCalculator.shouldBeVisible(tasks, day), isTrue);
    });

    test('no cuenta tareas de otros días', () {
      final tasks = [
        _task('a', day),
        _task('b', day),
        _task('c', day.subtract(const Duration(days: 1))),
      ];
      expect(QuestCalculator.shouldBeVisible(tasks, day), isFalse);
    });
  });

  group('QuestCalculator.completedCountOn (misma base que la alerta de racha)',
      () {
    test('cuenta tareas completadas HOY por completedAt (no scheduledDate)', () {
      final tasks = [
        _task('a', day, isCompleted: true, completedAt: DateTime(2026, 8, 10, 9)),
        _task('b', day, isCompleted: true, completedAt: DateTime(2026, 8, 10, 12)),
        _task('c', day), // pendiente
        _task('d', day.subtract(const Duration(days: 1)),
            isCompleted: true, completedAt: DateTime(2026, 8, 9, 9)),
      ];
      expect(QuestCalculator.completedCountOn(tasks, day), 2);
    });

    test('una tarea de AYER marcada HOY cuenta como completada hoy', () {
      final tasks = [
        _task('a', day.subtract(const Duration(days: 1)),
            isCompleted: true, completedAt: DateTime(2026, 8, 10, 8)),
      ];
      expect(QuestCalculator.completedCountOn(tasks, day), 1);
    });
  });

  group('H2 regla de producto: las subtareas NO cuentan para la quest', () {
    test('una subtarea completada NO sube completedToday', () {
      final tasks = [
        _task('a', day,
            isCompleted: true, completedAt: DateTime(2026, 8, 10, 9)),
        _task('s1', day,
            isCompleted: true,
            completedAt: DateTime(2026, 8, 10, 10),
            isSubtask: true,
            parentTaskId: 'a'),
      ];
      expect(QuestCalculator.completedCountOn(tasks, day), 1,
          reason: 'solo la principal cuenta; la subtarea NO es una "misión"');
    });

    test('3 subtareas completadas NO hacen visible la quest', () {
      final tasks = [
        _task('s1', day, isSubtask: true, parentTaskId: 'a'),
        _task('s2', day, isSubtask: true, parentTaskId: 'a'),
        _task('s3', day, isSubtask: true, parentTaskId: 'a'),
      ];
      expect(QuestCalculator.shouldBeVisible(tasks, day), isFalse,
          reason: 'las subtareas son sub-bloques, no "misiones"');
    });

    test('una principal con subtareas NO alcanza las 3 misiones requeridas', () {
      final tasks = [
        _task('a', day),
        _task('s1', day, isSubtask: true, parentTaskId: 'a'),
        _task('s2', day, isSubtask: true, parentTaskId: 'a'),
      ];
      expect(QuestCalculator.shouldBeVisible(tasks, day), isFalse,
          reason: 'solo hay 1 tarea principal (a), no 3');
    });

    test('con 2 tareas (cada una con 4 subtareas) la quest NO es visible', () {
      // 2 principales + 8 subtareas = 10 ítems, pero la quest exige 3 PRINCIPALES.
      final tasks = [
        _task('a', day),
        _task('a1', day, isSubtask: true, parentTaskId: 'a'),
        _task('a2', day, isSubtask: true, parentTaskId: 'a'),
        _task('a3', day, isSubtask: true, parentTaskId: 'a'),
        _task('a4', day, isSubtask: true, parentTaskId: 'a'),
        _task('b', day),
        _task('b1', day, isSubtask: true, parentTaskId: 'b'),
        _task('b2', day, isSubtask: true, parentTaskId: 'b'),
        _task('b3', day, isSubtask: true, parentTaskId: 'b'),
        _task('b4', day, isSubtask: true, parentTaskId: 'b'),
      ];
      expect(QuestCalculator.shouldBeVisible(tasks, day), isFalse,
          reason: 'solo hay 2 principales; las subs no inflan la quest');
    });

    test(
        'una tarea con 3 subtareas al marcarla solo sube 1 en completedToday',
        () {
      // Simula el arrastre de la principal: la principal + 3 subtareas marcadas
      // arrastradas cuentan como UNA "misión" completada, no como 4.
      final tasks = [
        _task('a', day,
            isCompleted: true, completedAt: DateTime(2026, 8, 10, 9)),
        _task('s1', day,
            isCompleted: true,
            completedAt: DateTime(2026, 8, 10, 9),
            isSubtask: true,
            parentTaskId: 'a'),
        _task('s2', day,
            isCompleted: true,
            completedAt: DateTime(2026, 8, 10, 9),
            isSubtask: true,
            parentTaskId: 'a'),
        _task('s3', day,
            isCompleted: true,
            completedAt: DateTime(2026, 8, 10, 9),
            isSubtask: true,
            parentTaskId: 'a'),
      ];
      expect(QuestCalculator.completedCountOn(tasks, day), 1,
          reason: 'arrastre = 1 sola misión completada, no N+1');
    });
  });
}