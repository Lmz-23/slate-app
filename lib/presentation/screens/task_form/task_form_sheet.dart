import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/extensions/datetime_extensions.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/enums/task_priority.dart';
import '../../../domain/enums/recurrence_type.dart';
import '../../../application/providers/task_provider.dart';
import '../../../application/providers/category_provider.dart';
import '../../../application/providers/speech_provider.dart';
import '../../../presentation/widgets/voice_input_button.dart';
import 'widgets/priority_selector.dart';
import 'widgets/category_selector.dart';
import 'widgets/recurrence_selector.dart';

class TaskFormSheet extends ConsumerStatefulWidget {
  final DateTime initialDate;
  final String? taskId;
  final bool isVoiceMode;

  const TaskFormSheet({
    super.key,
    required this.initialDate,
    this.taskId,
    this.isVoiceMode = false,
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
  TaskPriority _priority = TaskPriority.normal;
  RecurrenceType _recurrence = RecurrenceType.none;
  List<int> _recurrenceDays = [];
  String? _categoryId;
  bool _isVoiceActive = false;
  String _partialText = '';

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
            _priority = task.priority;
            _recurrence = task.recurrence;
            _recurrenceDays = task.recurrenceDays ?? [];
            _categoryId = task.categoryId;
          });
        }
      });
    }

    if (widget.isVoiceMode) {
      _startVoiceRecognition();
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

  Future<void> _startVoiceRecognition() async {
    final speechService = ref.read(speechProvider);
    final available = await speechService.initialize();

    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reconocimiento de voz no disponible')),
        );
      }
      return;
    }

    setState(() => _isVoiceActive = true);

    await speechService.startListening(
      onResult: (words) {
        setState(() {
          _titleController.text = words;
          _partialText = '';
        });
      },
      onPartialResult: (words) {
        setState(() {
          _partialText = words;
        });
      },
    );
  }

  Future<void> _stopVoiceRecognition() async {
    final speechService = ref.read(speechProvider);
    await speechService.stopListening();
    setState(() => _isVoiceActive = false);
    _partialText = '';
  }

  void _showDeleteDialog() {
    if (_existingTask == null) return;

    final tasks = ref.read(tasksProvider);
    final hasRecurrence = _existingTask!.parentTaskId != null ||
        _existingTask!.recurrence != RecurrenceType.none ||
        tasks.any((t) => t.parentTaskId == _existingTask!.id);

    if (hasRecurrence) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
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
                onTap: () {
                  Navigator.pop(context);
                  _deleteTask(this.context, deleteAll: false);
                },
              ),
              ListTile(
                leading: const Icon(Icons.event_repeat, color: AppColors.error),
                title: const Text(
                  'Todas las ocurrencias',
                  style: TextStyle(color: AppColors.error),
                ),
                subtitle: const Text(
                  'Eliminar tarea y todas sus repeticiones',
                  style: TextStyle(color: AppColors.textSecondary),
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
              child: const Text('Cancelar'),
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
    final isListening = ref.watch(isListeningProvider);
    final isEditing = widget.taskId != null;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                  color: AppColors.textTertiary,
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
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Row(
                  children: [
                    if (isEditing)
                      IconButton(
                        onPressed: _showDeleteDialog,
                        icon: const Icon(Icons.delete_outline, color: AppColors.error),
                      ),
                    if (_isVoiceActive || isListening)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.hearing, size: 14, color: AppColors.error),
                            SizedBox(width: 4),
                            Text(
                              'Escuchando',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.error,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            // Voice input with animated button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _titleController,
                        autofocus: widget.isVoiceMode || _isVoiceActive,
                        style: const TextStyle(
                          fontSize: 18,
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: _isVoiceActive || isListening
                              ? 'Habla ahora...'
                              : '¿Qué necesitas hacer?',
                          prefixIcon: _isVoiceActive || isListening
                              ? const Icon(Icons.mic, color: AppColors.primary)
                              : null,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _partialText = '';
                          });
                        },
                      ),
                      // Show partial recognized text in real-time
                      if (_partialText.isNotEmpty && _partialText != _titleController.text)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.auto_awesome,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    _partialText,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.primary,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                VoiceInputButton(
                  isListening: _isVoiceActive || isListening,
                  onStart: _startVoiceRecognition,
                  onStop: _stopVoiceRecognition,
                ),
              ],
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
              style: const TextStyle(color: AppColors.textPrimary),
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
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                ),
                child: Text(
                  isEditing ? 'Guardar' : 'Crear tarea',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Subtareas',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
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
                foregroundColor: AppColors.primary,
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
              const Icon(Icons.drag_indicator,
                  size: 16, color: AppColors.textTertiary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: controller,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
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
                icon: const Icon(Icons.close,
                    size: 16, color: AppColors.textTertiary),
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
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lock_outline,
            size: 20,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '${lockedDate.formattedDate} · la fecha sigue a la tarea principal',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderHint() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.notifications_active_outlined,
            size: 16,
            color: AppColors.primary,
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Por defecto te avisaremos justo a la hora de la tarea. '
              'Puedes adelantar el aviso en Ajustes › Recordatorios.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimeRow() {
    return Row(
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
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 20, color: AppColors.textSecondary),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    _selectedDate.formattedDate,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
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
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time, size: 20, color: AppColors.textSecondary),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    _selectedTime?.format(context) ?? 'Sin hora',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
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
            onPressed: () => setState(() => _selectedTime = null),
            icon: const Icon(Icons.close, size: 20, color: AppColors.textTertiary),
          ),
        ],
      ],
    );
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
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              surface: AppColors.surface,
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
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              surface: AppColors.surface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (time != null) {
      setState(() => _selectedTime = time);
    }
  }

  Future<void> _saveTask() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El título es obligatorio')),
      );
      return;
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
}
