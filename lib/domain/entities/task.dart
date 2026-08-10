import 'package:equatable/equatable.dart';
import '../enums/task_priority.dart';
import '../enums/recurrence_type.dart';

class Task extends Equatable {
  final String id;
  final String title;
  final String? notes;
  final DateTime? scheduledTime;
  final DateTime scheduledDate;
  final bool isCompleted;
  final TaskPriority priority;
  final RecurrenceType recurrence;
  final List<int>? recurrenceDays;
  final String? categoryId;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? parentTaskId;

  /// F4 (subtareas): `true` cuando esta tarea es una SUBTAREA de la tarea
  /// cuyo id es [parentTaskId].
  ///
  /// Es la marca AUTORITATIVA que distingue una subtarea de una ocurrencia de
  /// serie recurrente (ambas usan [parentTaskId]). DECISIÓN TÉCNICA F4: se
  /// prefiere un flag explícito y persistido (retrocompatible: `false` por
  /// defecto) a inferir el rol por heurísticas como `recurrence == none`,
  /// porque el rol debe sobrevivir a backups/restores y no depender del valor
  /// actual de otros campos.
  final bool isSubtask;

  /// F4 (subtareas): `true` cuando el +2 XP de esta subtarea YA fue otorgado y
  /// todavía está en pie (la subtarea está completada por marcado EXPLÍCITO).
  ///
  /// El arrastre de la principal completa subtareas SIN otorgar XP; esta marca
  /// permite que al REVERTIR el arrastre se resten -2 solo a las subtareas
  /// cuyo XP sí se concedió (conservación exacta anti-exploit). Se persiste
  /// para que la simetría sobreviva a reinicios.
  final bool subtaskXpGranted;

  const Task({
    required this.id,
    required this.title,
    this.notes,
    this.scheduledTime,
    required this.scheduledDate,
    this.isCompleted = false,
    this.priority = TaskPriority.normal,
    this.recurrence = RecurrenceType.none,
    this.recurrenceDays,
    this.categoryId,
    required this.createdAt,
    this.completedAt,
    this.parentTaskId,
    this.isSubtask = false,
    this.subtaskXpGranted = false,
  });

  Task copyWith({
    String? id,
    String? title,
    String? notes,
    DateTime? scheduledTime,
    DateTime? scheduledDate,
    bool? isCompleted,
    TaskPriority? priority,
    RecurrenceType? recurrence,
    List<int>? recurrenceDays,
    String? categoryId,
    DateTime? createdAt,
    DateTime? completedAt,
    String? parentTaskId,
    bool? isSubtask,
    bool? subtaskXpGranted,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      isCompleted: isCompleted ?? this.isCompleted,
      priority: priority ?? this.priority,
      recurrence: recurrence ?? this.recurrence,
      recurrenceDays: recurrenceDays ?? this.recurrenceDays,
      categoryId: categoryId ?? this.categoryId,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      isSubtask: isSubtask ?? this.isSubtask,
      subtaskXpGranted: subtaskXpGranted ?? this.subtaskXpGranted,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        notes,
        scheduledTime,
        scheduledDate,
        isCompleted,
        priority,
        recurrence,
        recurrenceDays,
        categoryId,
        createdAt,
        completedAt,
        parentTaskId,
        isSubtask,
        subtaskXpGranted,
      ];
}