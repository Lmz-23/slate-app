import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/task.dart';
import '../../domain/enums/task_priority.dart';
import '../../domain/enums/recurrence_type.dart';
import '../../data/hive/boxes/tasks_box.dart';
import '../../data/repositories/task_repository_impl.dart';
import 'now_provider.dart';
import 'notification_providers.dart';
import 'settings_provider.dart';

final tasksBoxProvider = Provider<TasksBox>((ref) {
  throw UnimplementedError('Must be overridden');
});

final taskRepositoryProvider = Provider<TaskRepositoryImpl>((ref) {
  return TaskRepositoryImpl(ref.watch(tasksBoxProvider));
});

final tasksProvider = StateNotifierProvider<TasksNotifier, List<Task>>((ref) {
  return TasksNotifier(ref.watch(taskRepositoryProvider), ref);
});

final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = ref.read(nowProvider).value ?? DateTime.now();
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
  final Ref _ref;
  final _uuid = const Uuid();

  TasksNotifier(this._repository, this._ref) : super(_repository.getAll());

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

    // Conecta el sistema de notificaciones: programa el recordatorio de la
    // tarea creada (si tiene horario) y el de cada ocurrencia generada de la
    // serie recurrente (cada una tiene su propio id derivado).
    await _syncReminderForTask(task);
    final generated = _repository
        .getAll()
        .where((t) => t.parentTaskId == task.id)
        .toList();
    for (final occurrence in generated) {
      await _syncReminderForTask(occurrence);
    }

    // Slate System: al GUARDAR la tarea (no al disparar) se genera en segundo
    // plano la variante temática con IA si el usuario activó "Textos con IA".
    // Solo para la tarea raíz: las ocurrencias comparten título y no merecen
    // llamadas repetidas a la API.
    unawaited(_maybeGenerateThematicVariant(task));
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
    // Reprograma el recordatorio con el MISMO id (se deriva de task.id): si la
    // fecha/hora cambió, el zonedSchedule nuevo reemplaza al anterior; si
    // perdió el horario o se completó, syncTaskReminder lo cancela.
    await _syncReminderForTask(task);
    // Slate System: al guardar una edición se regenera la variante IA si el
    // título cambió (la clave de caché incluye el título normalizado).
    unawaited(_maybeGenerateThematicVariant(task));
  }

  Future<void> deleteTask(String id) async {
    // Actualización SÍNCRONA y optimista: el ítem desaparece del estado (y por
    // tanto del árbol de widgets) antes de que termine el borrado en Hive.
    // Esto evita el assert "A dismissed Dismissible widget is still part of
    // the tree" cuando se borra una tarjeta desde el Dismissible.
    state = state.where((t) => t.id != id).toList();
    await _repository.delete(id);
    await _cancelReminder(id);
  }

  /// Elimina una serie completa de tareas recurrentes.
  ///
  /// Dada CUALQUIER ocurrencia de la serie (incluida una hija con
  /// `parentTaskId`), sube hasta la RAÍZ (la tarea original cuyo id es igual
  /// a `parentTaskId`; si la tarea dada no tiene `parentTaskId`, ella es la
  /// raíz) y borra la raíz junto con todas las tareas que tengan
  /// `parentTaskId == idRaíz`.
  ///
  /// El estado se actualiza de forma SÍNCRONA (optimista) antes de esperar el
  /// borrado en Hive por las mismas razones que [deleteTask].
  Future<void> deleteTaskAndRecurring(String id) async {
    final found = _repository.getById(id);
    if (found == null) return;

    // Subir a la raíz de la serie. `root` no es anulable para que el
    // promotor de tipos no pierda la no-nulidad dentro del bucle.
    var root = found;
    while (root.parentTaskId != null) {
      final parent = _repository.getById(root.parentTaskId!);
      if (parent == null) break;
      root = parent;
    }

    final rootId = root.id;
    final idsToDelete = state
        .where((t) => t.id == rootId || t.parentTaskId == rootId)
        .map((t) => t.id)
        .toSet();

    // Actualización síncrona del estado antes del borrado asíncrono.
    state = state.where((t) => !idsToDelete.contains(t.id)).toList();

    for (final taskId in idsToDelete) {
      await _repository.delete(taskId);
      // Cancela el recordatorio de CADA ocurrencia de la serie.
      await _cancelReminder(taskId);
    }
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

      // Al completar se CANCELA el recordatorio de esa ocurrencia; al
      // desmarcar se reprograma (si sigue con horario y notificaciones
      // activas).
      if (updated.isCompleted) {
        await _cancelReminder(updated.id);
      } else {
        await _syncReminderForTask(updated);
      }
    }
  }

  Future<void> _syncReminderForTask(Task task) async {
    final manager = _ref.read(reminderManagerProvider);
    final settings = _ref.read(settingsProvider);
    try {
      await manager.syncTaskReminder(task, settings);
    } catch (e) {
      debugPrint('TasksNotifier: error sincronizando recordatorio: $e');
    }
  }

  Future<void> _cancelReminder(String taskId) async {
    final manager = _ref.read(reminderManagerProvider);
    try {
      await manager.cancelTaskReminder(taskId);
    } catch (e) {
      debugPrint('TasksNotifier: error cancelando recordatorio: $e');
    }
  }

  /// Slate System: genera (si corresponde) la variante temática con IA del
  /// recordatorio de [task]. No-op si el tema o el toggle "Textos con IA"
  /// están desactivados o no hay API key (el generador lo comprueba interno).
  Future<void> _maybeGenerateThematicVariant(Task task) async {
    final settings = _ref.read(settingsProvider);
    if (!settings.useAIThematicTexts || !settings.slateSystemTheme) return;
    try {
      final generator = _ref.read(thematicTextsGeneratorProvider);
      await generator.ensureTaskVariant(task);
    } catch (e) {
      debugPrint('TasksNotifier: error generando texto temático: $e');
    }
  }
}