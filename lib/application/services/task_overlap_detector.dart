import 'package:flutter/material.dart' show TimeOfDay;

import '../../domain/entities/task.dart';
import '../../domain/enums/recurrence_type.dart';
import 'recurrence_calculator.dart';
import 'task_schedule_calculator.dart';

/// Horario propuesto por el formulario para una tarea nueva o en edición
/// (Addendum 2, A12). Solo transporta los datos necesarios para proyectar el
/// rango y sus posibles ocurrencias recurrentes; no es un `Task` completo.
class TaskDraftSchedule {
  final DateTime scheduledDate;
  final TimeOfDay? startTime;
  final int? durationMinutes;
  final RecurrenceType recurrence;
  final List<int>? recurrenceDays;

  const TaskDraftSchedule({
    required this.scheduledDate,
    required this.startTime,
    required this.durationMinutes,
    this.recurrence = RecurrenceType.none,
    this.recurrenceDays,
  });
}

/// Conflicto de horario detectado con una tarea existente (Addendum 2/3,
/// A12/A14). Representa el rango de la tarea EXISTENTE ([taskId]) que se
/// solapa con el borrador que se intenta guardar.
class TaskConflict {
  final String taskId;
  final String title;
  final DateTime start;
  final DateTime end;

  /// Día de la ocurrencia del BORRADOR en la que se detectó el conflicto
  /// (relevante para series recurrentes: puede no ser la fecha original).
  final DateTime occurrenceDate;

  /// `true` si la tarea existente en conflicto es una ocurrencia de una
  /// serie recurrente (tiene `parentTaskId` y no es subtarea).
  final bool isRecurringOccurrence;

  /// A14: `true` si la tarea existente empieza ANTES que el borrador, lo que
  /// permite ofrecer "Acortar" (truncar su fin al inicio del borrador) como
  /// resolución no destructiva.
  final bool canTruncate;

  /// A14: duración resultante (minutos) si se trunca la tarea existente.
  /// `null` si [canTruncate] es `false`.
  final int? truncatedDurationMinutes;

  const TaskConflict({
    required this.taskId,
    required this.title,
    required this.start,
    required this.end,
    required this.occurrenceDate,
    required this.isRecurringOccurrence,
    required this.canTruncate,
    required this.truncatedDurationMinutes,
  });
}

/// Contrato de consulta de solapamiento (Addendum 2, A12). Se expone como
/// interfaz para poder sustituirla por un doble trivial en tests de widget.
abstract class TaskOverlapQuery {
  TaskConflict? findFirstConflict(TaskDraftSchedule draft, {String? editingTaskId});
}

/// Calculador PURO de solapamiento de horarios (Addendum 2, A12).
///
/// Definición: dos rangos A y B se solapan si y solo si
/// `A.start < B.end && B.start < A.end` (semiabiertos `[start, end)`;
/// 13:00-14:00 y 14:00-15:00 NO son conflicto). Se comparan instantes
/// absolutos, nunca horas del día, lo que resuelve el cruce de medianoche sin
/// caso especial.
///
/// Exclusiones del conjunto de candidatas: sin horario, subtareas, legacy sin
/// `durationMinutes`, la propia tarea en edición y TODA la serie a la que
/// pertenece (raíz + hijas), y tareas completadas (hechos históricos, no
/// compromisos; también prerrequisito de la exclusión anti-exploit RG23).
///
/// Horizonte de proyección de recurrencia: 35 días (mínimo que garantiza al
/// menos una ocurrencia de cada tipo soportado, incluido `monthly`), usando
/// la MISMA regla que el generador real de ocurrencias
/// ([RecurrenceCalculator]). Se reporta solo el PRIMER conflicto cronológico.
class TaskOverlapDetector implements TaskOverlapQuery {
  /// Horizonte de proyección de ocurrencias recurrentes del borrador.
  static const int recurrenceCheckHorizonDays = 35;

  final List<Task> _tasks;

  /// Índice por día calendario (medianoche UTC) de tareas candidatas con
  /// rango resoluble, precomputado una sola vez por instancia (se reconstruye
  /// cuando cambia `tasksProvider`, no en cada guardado).
  final Map<DateTime, List<Task>> _candidatesByDay;

  TaskOverlapDetector(List<Task> tasks)
      : _tasks = tasks,
        _candidatesByDay = _buildIndex(tasks);

  static DateTime _dayKey(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  static Map<DateTime, List<Task>> _buildIndex(List<Task> tasks) {
    final index = <DateTime, List<Task>>{};
    for (final task in tasks) {
      if (!_isCandidateBase(task)) continue;
      final range = TaskScheduleCalculator.effectiveRange(task);
      if (range == null) continue;
      final key = _dayKey(range.start);
      index.putIfAbsent(key, () => []).add(task);
    }
    return index;
  }

  /// Filtro de candidatura que NO depende de la tarea en edición (se aplica
  /// una sola vez al construir el índice): excluye subtareas, completadas y
  /// tareas sin duración conocida.
  static bool _isCandidateBase(Task task) {
    if (task.isSubtask) return false;
    if (task.isCompleted) return false;
    if (task.scheduledTime == null) return false;
    if (task.durationMinutes == null || task.durationMinutes! <= 0) return false;
    return true;
  }

  @override
  TaskConflict? findFirstConflict(
    TaskDraftSchedule draft, {
    String? editingTaskId,
  }) {
    final startTime = draft.startTime;
    final durationMinutes = draft.durationMinutes;
    if (startTime == null || durationMinutes == null || durationMinutes <= 0) {
      return null;
    }

    final excludedIds = _excludedIdsForSeries(editingTaskId);

    final occurrenceDates = <DateTime>[
      draft.scheduledDate,
      ...RecurrenceCalculator.occurrenceDates(
        base: draft.scheduledDate,
        recurrence: draft.recurrence,
        recurrenceDays: draft.recurrenceDays,
        days: recurrenceCheckHorizonDays,
      ),
    ];

    final draftStartMinuteOfDay = startTime.hour * 60 + startTime.minute;

    for (final occDate in occurrenceDates) {
      final draftStart = DateTime(
        occDate.year,
        occDate.month,
        occDate.day,
        startTime.hour,
        startTime.minute,
      );
      final draftEnd = draftStart.add(Duration(minutes: durationMinutes));

      TaskConflict? bestForThisDate;

      // Ventana D-1/D/D+1: un rango candidato indexado en un día vecino puede
      // seguir solapando el borrador si cruza medianoche.
      for (final offset in [-1, 0, 1]) {
        final key = _dayKey(draftStart.add(Duration(days: offset)));
        final candidates = _candidatesByDay[key];
        if (candidates == null) continue;

        for (final candidate in candidates) {
          if (excludedIds.contains(candidate.id)) continue;
          final range = TaskScheduleCalculator.effectiveRange(candidate);
          if (range == null) continue;

          final overlaps =
              draftStart.isBefore(range.end) && range.start.isBefore(draftEnd);
          if (!overlaps) continue;

          if (bestForThisDate == null ||
              range.start.isBefore(bestForThisDate.start)) {
            final candidateStartMinuteOfDay =
                candidate.scheduledTime!.hour * 60 +
                    candidate.scheduledTime!.minute;
            final canTruncate =
                candidateStartMinuteOfDay < draftStartMinuteOfDay;
            bestForThisDate = TaskConflict(
              taskId: candidate.id,
              title: candidate.title,
              start: range.start,
              end: range.end,
              occurrenceDate: occDate,
              isRecurringOccurrence:
                  candidate.parentTaskId != null && !candidate.isSubtask,
              canTruncate: canTruncate,
              truncatedDurationMinutes: canTruncate
                  ? draftStartMinuteOfDay - candidateStartMinuteOfDay
                  : null,
            );
          }
        }
      }

      if (bestForThisDate != null) return bestForThisDate;
    }

    return null;
  }

  /// IDs a excluir del conjunto de candidatas cuando se edita una tarea
  /// existente: la propia tarea, la raíz de su serie (si la hay) y TODAS las
  /// hijas de esa raíz. Evita falsos conflictos con ocurrencias viejas de la
  /// MISMA serie que se está editando.
  Set<String> _excludedIdsForSeries(String? editingTaskId) {
    if (editingTaskId == null) return const {};

    final editingTask = _tasks.where((t) => t.id == editingTaskId).firstOrNull;
    final rootId = editingTask?.parentTaskId ?? editingTaskId;

    final excluded = <String>{editingTaskId, rootId};
    for (final t in _tasks) {
      if (t.parentTaskId == rootId) excluded.add(t.id);
    }
    return excluded;
  }
}
