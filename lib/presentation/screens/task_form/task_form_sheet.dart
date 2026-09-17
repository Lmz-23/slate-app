import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/extensions/datetime_extensions.dart';
import '../../../core/theme/slate_shapes.dart';
import '../../../core/theme/slate_theme_context.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/enums/task_priority.dart';
import '../../../domain/enums/recurrence_type.dart';
import '../../../application/providers/task_provider.dart';
import '../../../application/providers/category_provider.dart';
import '../../../application/providers/task_overlap_provider.dart';
import '../../../application/services/task_overlap_detector.dart';
import '../../widgets/common/slate_snackbar.dart';
import 'widgets/priority_selector.dart';
import 'widgets/category_selector.dart';
import 'widgets/recurrence_selector.dart';

class TaskFormSheet extends ConsumerStatefulWidget {
  final DateTime initialDate;
  final String? taskId;

  const TaskFormSheet({
    super.key,
    required this.initialDate,
    this.taskId,
  });

  @override
  ConsumerState<TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends ConsumerState<TaskFormSheet> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  // F4: editores de subtareas (UI mínima: campos de texto + filas dinámicas).
  final List<TextEditingController> _subtaskControllers = [];

  late DateTime _selectedDate;
  TimeOfDay? _selectedTime;

  /// Duración en minutos, obligatoria (>0) cuando `_selectedTime != null`
  /// (invariante I1, Addendum 2 A11). Se deriva de la hora de fin elegida por
  /// el usuario; nunca se expone un `TimeOfDay` de fin propio en el estado
  /// para no arrastrar el mismo problema de "día no autoritativo" que ya tiene
  /// `scheduledTime`.
  int? _durationMinutes;
  TaskPriority _priority = TaskPriority.normal;
  RecurrenceType _recurrence = RecurrenceType.none;
  List<int> _recurrenceDays = [];
  String? _categoryId;

  Task? _existingTask;

  /// F4-fix H3: ¿la tarea en edición es una SUBTAREA? Si lo es, la fecha NO se
  /// puede cambiar desde el formulario (sigue SIEMPRE a la de la principal).
  bool get _isEditingSubtask => _existingTask?.isSubtask ?? false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;

    if (widget.taskId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final tasks = ref.read(tasksProvider);
        final task = tasks.where((t) => t.id == widget.taskId).firstOrNull;
        if (task != null) {
          setState(() {
            _existingTask = task;
            _titleController.text = task.title;
            _notesController.text = task.notes ?? '';
            _selectedDate = task.scheduledDate;
            _selectedTime = task.scheduledTime != null
                ? TimeOfDay.fromDateTime(task.scheduledTime!)
                : null;
            _durationMinutes = task.durationMinutes;
            _priority = task.priority;
            _recurrence = task.recurrence;
            _recurrenceDays = task.recurrenceDays ?? [];
            _categoryId = task.categoryId;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    for (final controller in _subtaskControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _showDeleteDialog() {
    if (_existingTask == null) return;

    final tasks = ref.read(tasksProvider);
    final hasRecurrence = _existingTask!.parentTaskId != null ||
        _existingTask!.recurrence != RecurrenceType.none ||
        tasks.any((t) => t.parentTaskId == _existingTask!.id);

    if (hasRecurrence) {
      final slate = context.slate;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: slate.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SlateShapes.radiusLarge),
          ),
          title: Text(
            'Eliminar tarea',
            style: TextStyle(color: slate.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.today, color: slate.accent),
                title: Text(
                  'Solo este día',
                  style: TextStyle(color: slate.textPrimary),
                ),
                subtitle: Text(
                  'Eliminar solo esta ocurrencia',
                  style: TextStyle(color: slate.textSecondary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteTask(this.context, deleteAll: false);
                },
              ),
              ListTile(
                leading: Icon(Icons.event_repeat, color: slate.danger),
                title: Text(
                  'Todas las ocurrencias',
                  style: TextStyle(color: slate.danger),
                ),
                subtitle: Text(
                  'Eliminar tarea y todas sus repeticiones',
                  style: TextStyle(color: slate.textSecondary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteTask(this.context, deleteAll: true);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: TextStyle(color: slate.textSecondary)),
            ),
          ],
        ),
      );
    } else {
      _deleteTask(context, deleteAll: false);
    }
  }

  void _deleteTask(BuildContext context, {required bool deleteAll}) {
    if (_existingTask == null) return;

    if (deleteAll) {
      // deleteTaskAndRecurring sube a la raíz de la serie y borra la raíz +
      // todas las tareas con parentTaskId == idRaíz, funcione desde la
      // ocurrencia original o desde cualquier hija.
      ref.read(tasksProvider.notifier).deleteTaskAndRecurring(_existingTask!.id);
    } else {
      ref.read(tasksProvider.notifier).deleteTask(_existingTask!.id);
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final isEditing = widget.taskId != null;
    final slate = context.slate;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: slate.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(SlateShapes.radiusLarge),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: slate.textTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEditing ? 'Editar tarea' : 'Nueva tarea',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: slate.textPrimary,
                  ),
                ),
                Row(
                  children: [
                    if (isEditing)
                      IconButton(
                        onPressed: _showDeleteDialog,
                        icon: Icon(Icons.delete_outline, color: slate.danger),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _titleController,
              autofocus: true,
              style: TextStyle(
                fontSize: 18,
                color: slate.textPrimary,
              ),
              decoration: const InputDecoration(
                hintText: '¿Qué necesitas hacer?',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // F4-fix H3: al editar una subtarea NO se muestra el selector de
            // fecha/hora; en su lugar una fila solo-lectura con la fecha de la
            // principal (la invariante subtarea↔principal se mantiene).
            if (_isEditingSubtask)
              _buildSubtaskDateLockRow()
            else ...[
              _buildDateTimeRow(),
              if (_selectedTime != null) ...[
                const SizedBox(height: AppSpacing.sm),
                _buildReminderHint(),
              ],
            ],
            const SizedBox(height: AppSpacing.md),
            PrioritySelector(
              selected: _priority,
              onChanged: (p) => setState(() => _priority = p),
            ),
            const SizedBox(height: AppSpacing.md),
            CategorySelector(
              categories: categories,
              selectedId: _categoryId,
              onChanged: (id) => setState(() => _categoryId = id),
            ),
            const SizedBox(height: AppSpacing.md),
            RecurrenceSelector(
              selected: _recurrence,
              selectedDays: _recurrenceDays,
              onChanged: (r, days) => setState(() {
                _recurrence = r;
                _recurrenceDays = days ?? [];
              }),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _notesController,
              maxLines: 3,
              style: TextStyle(color: slate.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Notas (opcional)',
              ),
            ),
            if (!(_existingTask?.isSubtask ?? false)) ...[
              const SizedBox(height: AppSpacing.md),
              _buildSubtaskEditor(),
            ],
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveTask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: slate.accent,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(SlateShapes.radiusMedium),
                  ),
                ),
                child: Text(
                  isEditing ? 'Guardar' : 'Crear tarea',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: slate.onAccent,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  /// F4: editor MÍNIMO de subtareas. Cada fila es un texto (obligatorio para
  /// guardarse) con su botón de borrado; al guardar se crean las subtareas
  /// ligadas a la tarea principal. En modo edición solo AÑADE nuevas; las
  /// subtareas existentes se gestionan desde la tarjeta.
  Widget _buildSubtaskEditor() {
    final slate = context.slate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Subtareas',
              style: TextStyle(
                fontSize: 12,
                color: slate.textSecondary,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _subtaskControllers.add(TextEditingController());
                });
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Añadir'),
              style: TextButton.styleFrom(
                foregroundColor: slate.accent,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final controller in _subtaskControllers) ...[
          Row(
            children: [
              Icon(Icons.drag_indicator,
                  size: 16, color: slate.textTertiary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: controller,
                  style: TextStyle(
                    fontSize: 14,
                    color: slate.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Detalle de la subtarea',
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    final index = _subtaskControllers.indexOf(controller);
                    if (index >= 0) {
                      final removed = _subtaskControllers.removeAt(index);
                      removed.dispose();
                    }
                  });
                },
                icon: Icon(Icons.close,
                    size: 16, color: slate.textTertiary),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// F4-fix H3: fila solo-lectura que sustituye al selector de fecha cuando se
  /// edita una SUBTAREA. Muestra la fecha de la tarea principal y avisa de que
  /// la subtarea no tiene fecha propia. La invariante se refuerza además en
  /// `TasksNotifier.updateTask` (la subtarea se reasigna a la fecha de la
  /// principal en el guardado).
  Widget _buildSubtaskDateLockRow() {
    final slate = context.slate;
    final tasks = ref.watch(tasksProvider);
    final parentId = _existingTask?.parentTaskId;
    final parent = parentId != null
        ? tasks.where((t) => t.id == parentId).firstOrNull
        : null;
    final lockedDate = parent?.scheduledDate ??
        _existingTask?.scheduledDate ??
        widget.initialDate;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: slate.surfaceAlt,
        borderRadius: BorderRadius.circular(SlateShapes.radiusMedium),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lock_outline,
            size: 20,
            color: slate.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '${lockedDate.formattedDate} · la fecha sigue a la tarea principal',
              style: TextStyle(
                fontSize: 14,
                color: slate.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderHint() {
    final slate = context.slate;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: slate.surfaceAlt,
        borderRadius: BorderRadius.circular(SlateShapes.radiusSmall),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.notifications_active_outlined,
            size: 16,
            color: slate.accent,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Por defecto te avisaremos justo a la hora de la tarea. '
              'Puedes adelantar el aviso en Ajustes › Recordatorios.',
              style: TextStyle(
                fontSize: 12,
                color: slate.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimeRow() {
    final slate = context.slate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: slate.surfaceAlt,
                    borderRadius: BorderRadius.circular(SlateShapes.radiusMedium),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 20, color: slate.textSecondary),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        _selectedDate.formattedDate,
                        style: TextStyle(
                          fontSize: 14,
                          color: slate.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: GestureDetector(
                onTap: _pickTime,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: slate.surfaceAlt,
                    borderRadius: BorderRadius.circular(SlateShapes.radiusMedium),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time, size: 20, color: slate.textSecondary),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        _selectedTime?.format(context) ?? 'Sin hora',
                        style: TextStyle(
                          fontSize: 14,
                          color: slate.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_selectedTime != null) ...[
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                onPressed: () => setState(() {
                  // "Sin hora" limpia inicio y duración a la vez (Addendum 2,
                  // A11): una tarea sin inicio no puede tener fin.
                  _selectedTime = null;
                  _durationMinutes = null;
                }),
                icon: Icon(Icons.close, size: 20, color: slate.textTertiary),
              ),
            ],
          ],
        ),
        // Invariante I1: hora de fin obligatoria cuando hay hora de inicio.
        if (_selectedTime != null) ...[
          const SizedBox(height: AppSpacing.sm),
          GestureDetector(
            onTap: _pickEndTime,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: slate.surfaceAlt,
                borderRadius: BorderRadius.circular(SlateShapes.radiusMedium),
              ),
              child: Row(
                children: [
                  Icon(Icons.update, size: 20, color: slate.textSecondary),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    _durationMinutes != null && _durationMinutes! > 0
                        ? 'Hasta ${_endTimeLabel()}'
                        : 'Hora de fin (obligatoria)',
                    style: TextStyle(
                      fontSize: 14,
                      color: slate.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Hora de fin efectiva formateada en 24h (`14:30`), derivada de
  /// `_selectedTime + _durationMinutes` (sistema-visual-fase3.md §10).
  String _endTimeLabel() {
    final start = _selectedTime!;
    final endMinuteOfDay = (start.hour * 60 + start.minute + _durationMinutes!) % 1440;
    final hh = (endMinuteOfDay ~/ 60).toString().padLeft(2, '0');
    final mm = (endMinuteOfDay % 60).toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Future<void> _pickDate() async {
    // F4-fix H3: una subtarea nunca tiene fecha propia; el formulario no abre
    // el selector de fecha en edición de subtarea.
    if (_isEditingSubtask) return;

    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        final slate = context.slate;
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: slate.accent,
              surface: slate.surface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        final slate = context.slate;
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: slate.accent,
              surface: slate.surface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (time != null) {
      setState(() {
        _selectedTime = time;
        // Prefijar fin = inicio + 60 min al elegir/cambiar el inicio
        // (Addendum 2, A11).
        _durationMinutes = 60;
      });
    }
  }

  /// Selector de hora de FIN (Addendum 2, A11): se convierte a minutos de
  /// duración en el formulario (el estado nunca guarda un `TimeOfDay` de fin
  /// propio). `end <= start` se interpreta como cruce de medianoche
  /// (`(fin - inicio) mod 1440`); solo se rechaza duración == 0 (misma hora).
  Future<void> _pickEndTime() async {
    if (_selectedTime == null) return;

    final initialEnd = TimeOfDay(
      hour: (_selectedTime!.hour + 1) % 24,
      minute: _selectedTime!.minute,
    );

    final end = await showTimePicker(
      context: context,
      initialTime: _durationMinutes != null
          ? TimeOfDay(
              hour: ((_selectedTime!.hour * 60 +
                          _selectedTime!.minute +
                          _durationMinutes!) %
                      1440) ~/
                  60,
              minute: ((_selectedTime!.hour * 60 +
                          _selectedTime!.minute +
                          _durationMinutes!) %
                      1440) %
                  60,
            )
          : initialEnd,
      builder: (context, child) {
        final slate = context.slate;
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: slate.accent,
              surface: slate.surface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (end == null) return;

    final startMinuteOfDay = _selectedTime!.hour * 60 + _selectedTime!.minute;
    final endMinuteOfDay = end.hour * 60 + end.minute;
    final duration = (endMinuteOfDay - startMinuteOfDay) % 1440;

    if (duration <= 0) {
      if (mounted) {
        showSlateSnackBar(context, 'La hora de fin debe ser distinta a la de inicio');
      }
      return;
    }

    setState(() => _durationMinutes = duration);
  }

  Future<void> _saveTask() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      showSlateSnackBar(context, 'El título es obligatorio');
      return;
    }

    // Invariante I1 (Addendum 2, A11): hora de fin obligatoria si hay inicio.
    if (_selectedTime != null && (_durationMinutes == null || _durationMinutes! <= 0)) {
      showSlateSnackBar(context, 'La hora de fin es obligatoria');
      return;
    }

    // Addendum 2/3 (A12/A14): detección de solapamiento ANTES de llamar al
    // notifier. Se re-consulta tras cada "Acortar" (el índice se reconstruye
    // porque `taskOverlapQueryProvider` observa `tasksProvider`), por si el
    // borrador conflictúa con más de una tarea.
    if (_selectedTime != null) {
      final draft = TaskDraftSchedule(
        scheduledDate: _selectedDate,
        startTime: _selectedTime,
        durationMinutes: _durationMinutes,
        recurrence: _recurrence,
        recurrenceDays: _recurrenceDays.isEmpty ? null : _recurrenceDays,
      );

      while (true) {
        final query = ref.read(taskOverlapQueryProvider);
        final conflict = query.findFirstConflict(
          draft,
          editingTaskId: _existingTask?.id,
        );
        if (conflict == null) break;

        final action = await _showConflictDialog(conflict);
        if (action == null) return; // Cancelar: vuelve al formulario.
        if (action == _ConflictAction.truncate) {
          await _truncateConflict(conflict);
          if (!mounted) return;
          continue; // Re-consulta por si hay más conflictos.
        }
        break; // Guardar de todos modos.
      }
    }

    DateTime? scheduledTime;
    if (_selectedTime != null) {
      scheduledTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );
    }

    final tasksNotifier = ref.read(tasksProvider.notifier);
    late final String mainTaskId;

    if (_existingTask != null) {
      // F4-fix H3: al editar una SUBTAREA la fecha enviada siempre es la que
      // ya tenía (el selector está oculto). Aun así, `TasksNotifier.updateTask`
      // la REASIGNA a la fecha vigente de la principal como invariante.
      final updated = _existingTask!.copyWith(
        title: title,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        scheduledDate: _selectedDate,
        scheduledTime: scheduledTime,
        priority: _priority,
        recurrence: _recurrence,
        recurrenceDays: _recurrenceDays.isEmpty ? null : _recurrenceDays,
        categoryId: _categoryId,
        durationMinutes: _durationMinutes,
      );
      await tasksNotifier.updateTask(updated);
      mainTaskId = _existingTask!.id;
    } else {
      mainTaskId = await tasksNotifier.addTask(
        title: title,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        scheduledDate: _selectedDate,
        scheduledTime: scheduledTime,
        priorityIndex: _priority.index,
        recurrenceIndex: _recurrence.index,
        recurrenceDays: _recurrenceDays.isEmpty ? null : _recurrenceDays,
        categoryId: _categoryId,
        durationMinutes: _durationMinutes,
      );
    }

    // F4: crea las subtareas escritas en el editor, ligadas a la principal.
    if (!(_existingTask?.isSubtask ?? false)) {
      for (final controller in _subtaskControllers) {
        final subtaskTitle = controller.text.trim();
        if (subtaskTitle.isNotEmpty) {
          await tasksNotifier.addSubtask(
            title: subtaskTitle,
            parentTaskId: mainTaskId,
            scheduledDate: _selectedDate,
          );
        }
      }
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  /// Diálogo de conflicto de horario (Addendum 2/3, A12/A14). Tres acciones:
  /// Acortar (solo si `canTruncate`), Guardar de todos modos, Cancelar.
  Future<_ConflictAction?> _showConflictDialog(TaskConflict conflict) {
    final slate = context.slate;
    final rangeLabel =
        '${conflict.start.formattedTime}–${conflict.end.formattedTime}';
    return showDialog<_ConflictAction>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: slate.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SlateShapes.radiusLarge),
        ),
        title: Text(
          'Conflicto de horario',
          style: TextStyle(color: slate.textPrimary),
        ),
        content: Text(
          '"${conflict.title}" se solapa con esta tarea ($rangeLabel).',
          style: TextStyle(color: slate.textSecondary),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          if (conflict.canTruncate)
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, _ConflictAction.truncate),
              style: FilledButton.styleFrom(
                backgroundColor: slate.accent,
                foregroundColor: slate.onAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SlateShapes.radiusSmall),
                ),
              ),
              child: Text('Acortar "${conflict.title}"'),
            ),
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, _ConflictAction.saveAnyway),
            style: OutlinedButton.styleFrom(
              foregroundColor: slate.textPrimary,
              side: BorderSide(color: slate.outline),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(SlateShapes.radiusSmall),
              ),
            ),
            child: const Text('Guardar de todos modos'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancelar', style: TextStyle(color: slate.textSecondary)),
          ),
        ],
      ),
    );
  }

  /// Resuelve el conflicto acortando la tarea EXISTENTE en conflicto
  /// (Addendum 3, A14): relee la tarea por id (nunca aplica `copyWith` sobre
  /// el snapshot del diálogo), guarda de todos modos si mientras tanto se
  /// completó (guarda defensiva), y ofrece "Deshacer" (RG20).
  Future<void> _truncateConflict(TaskConflict conflict) async {
    final tasksNotifier = ref.read(tasksProvider.notifier);
    final current =
        ref.read(tasksProvider).where((t) => t.id == conflict.taskId).firstOrNull;
    if (current == null || current.isCompleted) return;

    final previousDuration = current.durationMinutes;
    await tasksNotifier.updateTask(
      current.copyWith(durationMinutes: conflict.truncatedDurationMinutes),
    );

    if (mounted && previousDuration != null) {
      showSlateSnackBar(
        context,
        '"${current.title}" acortada',
        actionLabel: 'Deshacer',
        onAction: () {
          ref.read(tasksProvider.notifier).updateTask(
                current.copyWith(durationMinutes: previousDuration),
              );
        },
      );
    }
  }
}

/// Acción elegida en el diálogo de conflicto de horario.
enum _ConflictAction { truncate, saveAnyway }
