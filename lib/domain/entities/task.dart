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
      ];
}