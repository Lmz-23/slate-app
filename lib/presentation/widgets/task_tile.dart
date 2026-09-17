import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/enums/task_priority.dart';
import '../../../domain/enums/recurrence_type.dart';
import '../../../application/providers/task_provider.dart';
import '../../../application/services/task_schedule_calculator.dart';
import '../../../core/extensions/datetime_extensions.dart';
import '../../../core/theme/slate_shapes.dart';
import '../../../core/theme/slate_theme_context.dart';
import 'common/slate_card.dart';

class TaskTile extends ConsumerStatefulWidget {
  final Task task;

  /// Se invoca al tocar cualquier parte de la tarjeta. Marca/desmarca la
  /// tarea como completada (toggle).
  final VoidCallback? onTap;

  /// Se invoca al mantener pulsada la tarjeta (P3): afordancia de edición,
  /// reemplaza al icono `more_horiz` retirado del diseño.
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

  /// Diálogo de confirmación de borrado (sistema-visual-fase3.md §6):
  /// contenedor `surface` radio 20, scrim `background` al 60%; dos botones en
  /// fila (`Cancelar` texto plano, `Eliminar` fondo `danger` radio 14) — es el
  /// único botón lleno de la app que usa `danger` en vez de `accent`.
  Future<bool> _confirmDelete(BuildContext context) async {
    final slate = context.slate;
    if (!_isPartOfSeries()) {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierColor: slate.background.withValues(alpha: 0.6),
        builder: (dialogContext) => AlertDialog(
          backgroundColor: slate.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SlateShapes.radiusLarge),
          ),
          title: Text(
            '¿Eliminar tarea?',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: slate.textPrimary,
            ),
          ),
          content: Text(
            '¿Eliminar esta tarea?',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 13,
              color: slate.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'Cancelar',
                style: TextStyle(color: slate.textSecondary),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: slate.danger,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SlateShapes.radiusSmall),
                ),
              ),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      );
      return confirmed ?? false;
    }

    final deleteSeries = await showDialog<bool>(
      context: context,
      barrierColor: slate.background.withValues(alpha: 0.6),
      builder: (dialogContext) => AlertDialog(
        backgroundColor: slate.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SlateShapes.radiusLarge),
        ),
        title: Text(
          'Eliminar tarea',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: slate.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.today, color: slate.textSecondary),
              title: Text(
                'Solo este día',
                style: TextStyle(color: slate.textPrimary),
              ),
              subtitle: Text(
                'Eliminar solo esta ocurrencia',
                style: TextStyle(color: slate.textSecondary),
              ),
              onTap: () => Navigator.pop(dialogContext, false),
            ),
            ListTile(
              leading: Icon(Icons.event_repeat, color: slate.danger),
              title: Text(
                'Eliminar toda la serie',
                style: TextStyle(color: slate.danger),
              ),
              subtitle: Text(
                'Eliminar tarea y todas sus repeticiones',
                style: TextStyle(color: slate.textSecondary),
              ),
              onTap: () => Navigator.pop(dialogContext, true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancelar', style: TextStyle(color: slate.textSecondary)),
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
          color: context.slate.danger,
          borderRadius: BorderRadius.circular(SlateShapes.radiusMedium),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      // P3: la edición pasa de un icono `more_horiz` a pulsación larga sobre
      // toda la tarjeta. El toque corto sigue siendo el toggle de completado
      // (SlateCard.onTap); ambos gestos conviven en el mismo árbol sin
      // conflicto (el arbitraje de gestos de Flutter distingue tap de
      // long-press).
      child: GestureDetector(
        onLongPress: widget.onEdit,
        child: SlateCard(
          onTap: widget.onTap,
          child: Row(
            children: [
              _buildStatusIndicator(context),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (_priorityDotColor(context) != null) ...[
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _priorityDotColor(context),
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
                                  ? context.slate.textTertiary
                                  : context.slate.textPrimary,
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
                            Icon(
                              Icons.access_time,
                              size: 12,
                              color: context.slate.textTertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _timeLabel(),
                              style: TextStyle(
                                fontSize: 12,
                                color: context.slate.textTertiary,
                              ),
                            ),
                          ],
                          if (task.notes != null && task.notes!.isNotEmpty) ...[
                            if (task.scheduledTime != null)
                              const SizedBox(width: 12),
                            Icon(
                              Icons.notes,
                              size: 12,
                              color: context.slate.textTertiary,
                            ),
                          ],
                        ],
                      ),
                    ],
                    // F4: subtareas anidadas de la tarea principal. Cada fila se
                    // toca para marcar/desmarcar SOLO esa subtarea (+2 XP).
                    if (subtasks.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...subtasks.map((s) => _buildSubtaskRow(context, s)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Formato del horario del tile (sistema-visual-fase3.md §10): 24h fijo,
  /// rango con en-dash sin espacios (`14:30–16:00`) cuando hay duración
  /// conocida; hora simple (`09:00`) si no (tarea legacy sin `durationMinutes`
  /// o sin fin conocido).
  String _timeLabel() {
    final range = TaskScheduleCalculator.effectiveRange(task);
    if (range != null) {
      return '${range.start.formattedTime}–${range.end.formattedTime}';
    }
    return task.scheduledTime!.formattedTime;
  }

  /// Regla del punto único de prioridad (sistema-visual-fase3.md §8): un solo
  /// indicador de 7px que codifica SOLO prioridad, nunca categoría. Prioridad
  /// normal no lleva punto (ausencia, no color neutro).
  Color? _priorityDotColor(BuildContext context) {
    switch (task.priority) {
      case TaskPriority.high:
        return context.slate.priorityHigh;
      case TaskPriority.medium:
        return context.slate.priorityMedium;
      case TaskPriority.normal:
        return null;
    }
  }

  /// Indicador visual de estado (completada o pendiente). No es táctil:
  /// el toggle se realiza tocando cualquier parte de la tarjeta.
  Widget _buildStatusIndicator(BuildContext context) {
    final slate = context.slate;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: task.isCompleted ? slate.success : Colors.transparent,
        border: Border.all(
          color: task.isCompleted ? slate.success : slate.outline,
          width: 2,
        ),
      ),
      child: task.isCompleted
          ? Icon(Icons.check, size: 16, color: slate.onSuccess)
          : null,
    );
  }

  /// F4: fila de subtarea anidada. Tocar la fila marca/desmarca la subtarea
  /// (+2 XP) SIN tocar la tarjeta de la principal.
  Widget _buildSubtaskRow(BuildContext context, Task subtask) {
    final slate = context.slate;
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
                color: subtask.isCompleted ? slate.success : Colors.transparent,
                border: Border.all(
                  color: subtask.isCompleted ? slate.success : slate.outline,
                  width: 1.5,
                ),
              ),
              child: subtask.isCompleted
                  ? Icon(Icons.check, size: 12, color: slate.onSuccess)
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                subtask.title,
                style: TextStyle(
                  fontSize: 13,
                  color: subtask.isCompleted ? slate.textTertiary : slate.textSecondary,
                  decoration: subtask.isCompleted ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
