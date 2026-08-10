import 'package:flutter_test/flutter_test.dart';

import 'package:slate_app/application/services/quest_calculator.dart';
import 'package:slate_app/domain/entities/task.dart';

Task _task(
  String id,
  DateTime scheduledDate, {
  bool isCompleted = false,
  DateTime? completedAt,
}) {
  return Task(
    id: id,
    title: 'Tarea $id',
    scheduledDate: scheduledDate,
    isCompleted: isCompleted,
    completedAt: completedAt,
    createdAt: scheduledDate,
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
}