import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/task.dart';
import '../../domain/enums/task_priority.dart';
import '../../domain/enums/recurrence_type.dart';
import '../../data/hive/boxes/tasks_box.dart';
import '../../data/repositories/task_repository_impl.dart';

final tasksBoxProvider = Provider<TasksBox>((ref) {
  throw UnimplementedError('Must be overridden');
});

final taskRepositoryProvider = Provider<TaskRepositoryImpl>((ref) {
  return TaskRepositoryImpl(ref.watch(tasksBoxProvider));
});

final tasksProvider = StateNotifierProvider<TasksNotifier, List<Task>>((ref) {
  return TasksNotifier(ref.watch(taskRepositoryProvider));
});

final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

final tasksBySelectedDateProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(tasksProvider);
  final selectedDate = ref.watch(selectedDateProvider);
  final startOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
  final endOfDay = startOfDay.add(const Duration(days: 1));
  return tasks.where((task) {
    return task.scheduledDate.isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
        task.scheduledDate.isBefore(endOfDay);
  }).toList()
    ..sort((a, b) {
      if (a.scheduledTime == null && b.scheduledTime == null) {
        return a.priority.sortOrder.compareTo(b.priority.sortOrder);
      }
      if (a.scheduledTime == null) return 1;
      if (b.scheduledTime == null) return -1;
      return a.scheduledTime!.compareTo(b.scheduledTime!);
    });
});

final scheduledTasksProvider = Provider<List<Task>>((ref) {
  return ref.watch(tasksBySelectedDateProvider).where((t) => t.scheduledTime != null).toList();
});

final unscheduledTasksProvider = Provider<List<Task>>((ref) {
  return ref.watch(tasksBySelectedDateProvider).where((t) => t.scheduledTime == null).toList();
});

class TasksNotifier extends StateNotifier<List<Task>> {
  final TaskRepositoryImpl _repository;
  final _uuid = const Uuid();

  TasksNotifier(this._repository) : super(_repository.getAll());

  void refresh() {
    state = _repository.getAll();
  }

  Future<void> addTask({
    required String title,
    String? notes,
    DateTime? scheduledTime,
    required DateTime scheduledDate,
    int priorityIndex = 0,
    int recurrenceIndex = 0,
    List<int>? recurrenceDays,
    String? categoryId,
  }) async {
    final task = Task(
      id: _uuid.v4(),
      title: title,
      notes: notes,
      scheduledTime: scheduledTime,
      scheduledDate: scheduledDate,
      priority: TaskPriority.values[priorityIndex],
      recurrence: RecurrenceType.values[recurrenceIndex],
      recurrenceDays: recurrenceDays,
      categoryId: categoryId,
      createdAt: DateTime.now(),
    );
    await _repository.add(task);
    await _generateRecurringTasks(task);
    refresh();
  }

  Future<void> _generateRecurringTasks(Task task) async {
    if (task.recurrence == RecurrenceType.none) return;

    final generatedTasks = <Task>[];
    DateTime nextDate = task.scheduledDate.add(const Duration(days: 1));

    for (int i = 0; i < 365; i++) {
      bool shouldGenerate = false;

      switch (task.recurrence) {
        case RecurrenceType.daily:
          shouldGenerate = true;
          break;
        case RecurrenceType.weekly:
          if (nextDate.weekday == task.scheduledDate.weekday) {
            shouldGenerate = true;
          }
          break;
        case RecurrenceType.specificDays:
          if (task.recurrenceDays != null && task.recurrenceDays!.contains(nextDate.weekday % 7)) {
            shouldGenerate = true;
          }
          break;
        case RecurrenceType.none:
          break;
      }

      if (shouldGenerate) {
        generatedTasks.add(task.copyWith(
          id: _uuid.v4(),
          scheduledDate: nextDate,
          createdAt: DateTime.now(),
          parentTaskId: task.id,
        ));
      }
      nextDate = nextDate.add(const Duration(days: 1));
    }

    for (final t in generatedTasks) {
      await _repository.add(t);
    }
  }

  Future<void> updateTask(Task task) async {
    await _repository.update(task);
    refresh();
  }

  Future<void> deleteTask(String id) async {
    await _repository.delete(id);
    refresh();
  }

  Future<void> toggleComplete(String id) async {
    final task = _repository.getById(id);
    if (task != null) {
      final updated = task.copyWith(
        isCompleted: !task.isCompleted,
        completedAt: !task.isCompleted ? DateTime.now() : null,
      );
      await _repository.update(updated);
      refresh();
    }
  }
}