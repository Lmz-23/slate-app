import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/enums/task_priority.dart';
import '../../../domain/enums/recurrence_type.dart';
import '../../../application/providers/task_provider.dart';
import '../../../application/providers/category_provider.dart';
import '../../../core/extensions/datetime_extensions.dart';
import 'common/slate_card.dart';

class TaskTile extends ConsumerStatefulWidget {
  final Task task;

  /// Se invoca al tocar cualquier parte de la tarjeta. Marca/desmarca la
  /// tarea como completada (toggle).
  final VoidCallback? onTap;

  /// Se invoca al tocar el icono de edición del extremo derecho.
  /// Este toque NO dispara [onTap].
  final VoidCallback? onEdit;

  /// Se invoca al confirmar la eliminación de SOLO esta ocurrencia.
  final VoidCallback? onDelete;

  /// Se invoca al confirmar la eliminación de TODA la serie.
  final VoidCallback? onDeleteSeries;

  /// F4: se invoca al tocar una SUBTAREA anidada (marca/desmarca la subtarea
  /// SIN tocar la principal).
  final ValueChanged<String>? onToggleSubtask;

  const TaskTile({
    super.key,
    required this.task,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onDeleteSeries,
    this.onToggleSubtask,
  });

  @override
  ConsumerState<TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends ConsumerState<TaskTile> {
  /// Modo de borrado elegido en el diálogo de confirmación del Dismissible.
  /// `true` = eliminar toda la serie; `false` = solo esta ocurrencia.
  bool _deleteSeries = false;

  Task get task => widget.task;

  /// Determina si la tarea pertenece a una serie recurrente.
  bool _isPartOfSeries() {
    if (task.parentTaskId != null) return true;
    if (task.recurrence != RecurrenceType.none) return true;
    final allTasks = ref.read(tasksProvider);
    return allTasks.any((t) => t.parentTaskId == task.id);
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    if (!_isPartOfSeries()) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text(
            'Eliminar tarea',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: const Text(
            '¿Eliminar esta tarea?',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Eliminar',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        ),
      );
      return confirmed ?? false;
    }

    final deleteSeries = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Eliminar tarea',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.today, color: AppColors.primary),
              title: const Text(
                'Solo este día',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              subtitle: const Text(
                'Eliminar solo esta ocurrencia',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              onTap: () => Navigator.pop(dialogContext, false),
            ),
            ListTile(
              leading: const Icon(Icons.event_repeat, color: AppColors.error),
              title: const Text(
                'Eliminar toda la serie',
                style: TextStyle(color: AppColors.error),
              ),
              subtitle: const Text(
                'Eliminar tarea y todas sus repeticiones',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              onTap: () => Navigator.pop(dialogContext, true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    // Cancelado: no deslizar.
    if (deleteSeries == null) return false;

    _deleteSeries = deleteSeries;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // P2-fix: categoriesProvider se lee (no se observa) porque las categorías
    // casi nunca cambian. Esto evita rebuilds innecesarios en todos los
    // TaskTiles cuando se modifica una categoría.
    final categories = ref.read(categoriesProvider);
    final category = task.categoryId != null
        ? categories.where((c) => c.id == task.categoryId).firstOrNull
        : null;
    // F4: subtareas directas de esta tarea (marca explícita isSubtask).
    // P1: se usa ref.read en lugar de ref.watch para evitar que cada TaskTile
    // se rebuild cuando CUALQUIER tarea cambia. Las subtareas se filtran aquí
    // directamente desde la lista actual sin suscribirse a cambios.
    final subtasks = ref
        .read(tasksProvider)
        .where((t) => t.parentTaskId == task.id && t.isSubtask)
        .toList();

    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) {
        if (_deleteSeries) {
          widget.onDeleteSeries?.call();
        } else {
          widget.onDelete?.call();
        }
        _deleteSeries = false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: SlateCard(
        onTap: widget.onTap,
        child: Row(
          children: [
            _buildStatusIndicator(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (category != null) ...[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.fromHex(category.colorHex),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          task.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: task.isCompleted
                                ? AppColors.textTertiary
                                : AppColors.textPrimary,
                            decoration: task.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (task.scheduledTime != null || task.notes != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (task.scheduledTime != null) ...[
                          const Icon(
                            Icons.access_time,
                            size: 12,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            task.scheduledTime!.formattedTime,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                        if (task.notes != null && task.notes!.isNotEmpty) ...[
                          if (task.scheduledTime != null)
                            const SizedBox(width: 12),
                          const Icon(
                            Icons.notes,
                            size: 12,
                            color: AppColors.textTertiary,
                          ),
                        ],
                      ],
                    ),
                  ],
                  // F4: subtareas anidadas de la tarea principal. Cada fila se
                  // toca para marcar/desmarcar SOLO esa subtarea (+2 XP).
                  if (subtasks.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...subtasks.map(_buildSubtaskRow),
                  ],
                ],
              ),
            ),
            _buildPriorityIndicator(),
            const SizedBox(width: 4),
            IconButton(
              onPressed: widget.onEdit,
              icon: const Icon(
                Icons.more_horiz,
                color: AppColors.textSecondary,
              ),
              tooltip: 'Editar tarea',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
          ],
        ),
      ),
    );
  }

  /// Indicador visual de estado (completada o pendiente). No es táctil:
  /// el toggle se realiza tocando cualquier parte de la tarjeta.
  Widget _buildStatusIndicator() {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: task.isCompleted ? AppColors.success : Colors.transparent,
        border: Border.all(
          color: task.isCompleted ? AppColors.success : AppColors.textTertiary,
          width: 2,
        ),
      ),
      child: task.isCompleted
          ? const Icon(Icons.check, size: 16, color: Colors.white)
          : null,
    );
  }

  Widget _buildPriorityIndicator() {
    if (task.priority == TaskPriority.normal) return const SizedBox.shrink();

    final color = switch (task.priority) {
      TaskPriority.high => AppColors.error,
      TaskPriority.medium => AppColors.warning,
      TaskPriority.normal => Colors.transparent,
    };

    return Container(
      width: 4,
      height: 40,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  /// F4: fila de subtarea anidada. Tocar la fila marca/desmarca la subtarea
  /// (+2 XP) SIN tocar la tarjeta de la principal.
  Widget _buildSubtaskRow(Task subtask) {
    return GestureDetector(
      onTap: () => widget.onToggleSubtask?.call(subtask.id),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    subtask.isCompleted ? AppColors.success : Colors.transparent,
                border: Border.all(
                  color: subtask.isCompleted
                      ? AppColors.success
                      : AppColors.textTertiary,
                  width: 1.5,
                ),
              ),
              child: subtask.isCompleted
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                subtask.title,
                style: TextStyle(
                  fontSize: 13,
                  color: subtask.isCompleted
                      ? AppColors.textTertiary
                      : AppColors.textSecondary,
                  decoration: subtask.isCompleted
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
