import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/task.dart';
import '../../domain/enums/task_priority.dart';
import '../../domain/enums/recurrence_type.dart';
import '../../data/hive/boxes/tasks_box.dart';
import '../../data/repositories/task_repository_impl.dart';
import '../services/timezone_service.dart';
import 'now_provider.dart';
import 'notification_providers.dart';
import 'player_provider.dart';
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
  // F4-fix H1: las SUBTAREAS se excluyen de las listas del día. Se renderizan
  // ÚNICAMENTE anidadas dentro de la tarjeta de su principal (TaskTile), por lo
  // que incluirlas aquí las duplicaría como tarjetas sueltas (p. ej. en "Sin
  // horario", ya que addSubtask no les asigna scheduledTime).
  return tasks.where((task) {
    return !task.isSubtask &&
        task.scheduledDate.isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
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

  /// Subtareas DIRECTAS de [parentId] (F4): tareas con `parentTaskId ==
  /// parentId` y `isSubtask == true`. Las ocurrencias de una serie recurrente
  /// (`parentTaskId != null && isSubtask == false`) NO entran aquí.
  List<Task> _subtasksOf(String parentId) {
    return state.where((t) => t.parentTaskId == parentId && t.isSubtask).toList();
  }

  PlayerNotifier get _player => _ref.read(playerProvider.notifier);

  /// Crea una tarea y devuelve su id (F4: el formulario lo usa como
  /// `parentTaskId` para las subtareas creadas en el mismo guardado).
  Future<String> addTask({
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

    // Slate System: al GUARDAR la tarea (no al disparar ni al programar) se
    // genera en segundo plano la variante temática con IA si el usuario activó
    // "Textos con IA". Solo para la tarea raíz: las ocurrencias comparten
    // título y no merecen llamadas repetidas a la API.
    unawaited(_maybeGenerateThematicVariants(task));

    return task.id;
  }

  /// F4: crea una SUBTAREA ligada a [parentTaskId] (la tarea principal).
  ///
  /// Las subtareas comparten la fecha de la principal, sin horario propio ni
  /// recurrencia (nunca generan serie propia). Se guardan SIN efectos
  /// colaterales (sin recordatorio ni variante IA): su único XP es el +2 al
  /// completarlas explícitamente.
  Future<void> addSubtask({
    required String title,
    required String parentTaskId,
    required DateTime scheduledDate,
  }) async {
    final task = Task(
      id: _uuid.v4(),
      title: title,
      scheduledDate: scheduledDate,
      priority: TaskPriority.normal,
      recurrence: RecurrenceType.none,
      categoryId: _repository.getById(parentTaskId)?.categoryId,
      createdAt: DateTime.now(),
      parentTaskId: parentTaskId,
      isSubtask: true,
    );
    await _repository.add(task);
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
        case RecurrenceType.monthly:
          // F4: misma "ancla" de día de mes que la tarea original, recortada al
          // último día del mes cuando este no la tiene (31→28/29/30; 30→28/29…
          // y 29-feb → 28 en años no bisiestos).
          final anchorDay = math.min(
            task.scheduledDate.day,
            DateTime(nextDate.year, nextDate.month + 1, 0).day,
          );
          if (nextDate.day == anchorDay) {
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
    final previous = _repository.getById(task.id);
    await _repository.update(task);
    refresh();
    // Reprograma el recordatorio con el MISMO id (se deriva de task.id): si la
    // fecha/hora cambió, el zonedSchedule nuevo reemplaza al anterior; si
    // perdió el horario o se completó, syncTaskReminder lo cancela.
    await _syncReminderForTask(task);
    // Slate System: al guardar una edición se regenera la variante IA si el
    // título cambió (la clave de caché incluye el título normalizado).
    unawaited(_maybeGenerateThematicVariants(task));

    // F4-fix H3 — invariante de fecha subtarea ↔ principal:
    //
    // - Al editar una PRINCIPAL y cambiar su fecha, se PROPAGA el cambio a sus
    //   subtareas DIRECTAS (misma fecha). Una subtarea nunca puede quedar en
    //   un día distinto del de su principal (el formulario además bloquea el
    //   campo de fecha al editar una subtarea, ver TaskFormSheet).
    // - Al editar una SUBTAREA, se REASIGNA su fecha a la de la principal como
    //   doble red de seguridad: aunque un llamador intente guardarla con otra
    //   fecha, la invariante se restaura en la capa de dominio.
    if (previous != null && !task.isSubtask) {
      if (!_isSameCalendarDay(previous.scheduledDate, task.scheduledDate)) {
        final children = _subtasksOf(task.id);
        for (final child in children) {
          await _repository.update(
            child.copyWith(scheduledDate: task.scheduledDate),
          );
        }
        if (children.isNotEmpty) refresh();
      }
    } else if (task.isSubtask && task.parentTaskId != null) {
      final parent = _repository.getById(task.parentTaskId!);
      if (parent != null &&
          !_isSameCalendarDay(parent.scheduledDate, task.scheduledDate)) {
        await _repository.update(
          task.copyWith(scheduledDate: parent.scheduledDate),
        );
        refresh();
      }
    }
  }

  static bool _isSameCalendarDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> deleteTask(String id) async {
    // F4: borrar la tarea principal arrastra también sus SUBTAREAS directas
    // (evita huérfanas con parentTaskId apuntando a un id inexistente).
    final children = _subtasksOf(id).map((t) => t.id).toList();

    // Actualización SÍNCRONA y optimista: el ítem desaparece del estado (y por
    // tanto del árbol de widgets) antes de que termine el borrado en Hive.
    // Esto evita el assert "A dismissed Dismissible widget is still part of
    // the tree" cuando se borra una tarjeta desde el Dismissible.
    state = state.where((t) => t.id != id && !children.contains(t.id)).toList();
    await _repository.delete(id);
    await _cancelReminder(id);
    for (final childId in children) {
      await _repository.delete(childId);
      await _cancelReminder(childId);
    }
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

  /// Marca/desmarca una tarea aplicando las reglas de producto de F4 y
  /// notificando al Jugador (XP) desde aquí.
  ///
  /// Devuelve el nivel alcanzado si la transición produjo un level-up NUEVO
  /// (`null` en caso contrario), igual que los métodos de [PlayerNotifier],
  /// para que la UI muestre el SnackBar "◆ Nivel subió" una sola vez.
  ///
  /// Reglas:
  /// - SUBTAREA explícita: completar da +2 XP ([PlayerNotifier.addSubtaskXp]),
  ///   desmarcar resta -2 ([PlayerNotifier.removeSubtaskXp]); el flag
  ///   [Task.subtaskXpGranted] sigue la concesión para conservar la simetría.
  /// - TAREA PRINCIPAL: completar da +XP por prioridad ([PlayerNotifier.addTaskXp])
  ///   y ARRASTRA todas sus subtareas a completadas SIN XP individual; al
  ///   desmarcar se revierte el arrastre (subtareas incompletas), se resta el
  ///   XP de la principal y -2 por cada subtarea cuyo XP sí se había concedido.
  Future<int?> toggleComplete(String id) async {
    final task = _repository.getById(id);
    if (task == null) return null;

    // ── Subtarea: toggle explícito con +2/-2 ────────────────────────────────
    if (task.isSubtask) {
      final updated = task.copyWith(
        isCompleted: !task.isCompleted,
        completedAt: !task.isCompleted ? DateTime.now() : null,
        subtaskXpGranted: !task.isCompleted,
      );
      await _repository.update(updated);
      int? levelUp;
      if (updated.isCompleted) {
        levelUp = await _player.addSubtaskXp();
      } else if (task.subtaskXpGranted) {
        // Desmarcar resta -2 SOLO si el +2 estaba en pie (marcado explícito).
        // Una subtarea arrastrada por la principal nunca recibió XP: si el
        // usuario la desmarca directamente, no se penaliza.
        await _player.removeSubtaskXp();
      }
      refresh();

      if (updated.isCompleted) {
        await _cancelReminder(updated.id);
      } else {
        await _syncReminderForTask(updated);
      }
      return levelUp;
    }

    // ── Tarea principal: toggle + arrastre/revertido de subtareas ──────────
    final children = _subtasksOf(task.id);
    final updated = task.copyWith(
      isCompleted: !task.isCompleted,
      completedAt: !task.isCompleted ? DateTime.now() : null,
    );
    await _repository.update(updated);
    int? levelUp;

    if (updated.isCompleted) {
      // Arrastre: completar las subtareas pendientes sin otorgar XP individual
      // (las ya completadas por marcado explícito conservan su XP y su marca).
      for (final child in children.where((c) => !c.isCompleted)) {
        await _repository.update(
          child.copyWith(isCompleted: true, completedAt: DateTime.now()),
        );
      }
      levelUp = await _player.addTaskXp(task.priority);

      await _cancelReminder(updated.id);
      for (final child in children.where((c) => !c.isCompleted)) {
        await _cancelReminder(child.id);
      }
    } else {
      // Revertido: descompletar todas las subtareas; restar -2 SOLO a las que
      // recibieron XP (subtaskXpGranted) para no penalizar el arrastre.
      for (final child in children.where((c) => c.isCompleted)) {
        await _repository.update(
          child.copyWith(
            isCompleted: false,
            completedAt: null,
            subtaskXpGranted: false,
          ),
        );
        if (child.subtaskXpGranted) {
          await _player.removeSubtaskXp();
        }
      }
      await _player.removeTaskXp(task.priority);

      await _syncReminderForTask(updated);
      for (final child in children.where((c) => c.isCompleted)) {
        await _syncReminderForTask(child);
      }
    }

    refresh();
    return levelUp;
  }

  Future<void> _syncReminderForTask(Task task) async {
    final manager = _ref.read(reminderManagerProvider);
    final settings = _ref.read(settingsProvider);
    try {
      // `now` en la zona horaria configurada: evita que un disparo ya pasado
      // llegue al plugin (que lanza ArgumentError). Cancelar es el lado seguro.
      await manager.syncTaskReminder(
        task,
        settings,
        now: TimezoneService.nowInTimezone(settings.timezone),
      );
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

  /// Slate System: genera (si corresponde) las variantes temáticas con IA.
  ///
  /// DECISIÓN (review `3142d33`, Hallazgos 1/4/6): este es el ÚNICO punto de
  /// generación con IA del sistema y se ejecuta SOLO al guardar tareas. El
  /// resolver de notificaciones es de solo lectura, por lo que programar
  /// NUNCA invoca a la IA.
  ///
  /// Gating del opt-in de CONTENIDO: se exige `useAIThematicTexts == true`.
  /// Con el toggle OFF la IA no se invoca nunca (la comprobación de API
  /// key/caché del generador es defensa adicional, no la condición del
  /// opt-in). La estética "Slate System" es la identidad única del producto y
  /// no forma parte del gating (los textos temáticos salen del catálogo
  /// local incluso sin IA).
  ///
  /// Genera la variante de la tarea guardada y las 3 variantes GLOBALES
  /// (resumen mañana/tarde + cierre de jornada), todas idempotentes por clave:
  /// si ya existen en caché o tienen una generación en curso, el generador no
  /// vuelve a llamar a la IA.
  Future<void> _maybeGenerateThematicVariants(Task task) async {
    final settings = _ref.read(settingsProvider);
    if (!settings.useAIThematicTexts) return;
    try {
      final generator = _ref.read(thematicTextsGeneratorProvider);
      await generator.ensureTaskVariant(task);
      await generator.ensureSummaryVariants();
    } catch (e) {
      debugPrint('TasksNotifier: error generando texto temático: $e');
    }
  }
}