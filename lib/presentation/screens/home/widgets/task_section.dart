import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../domain/entities/task.dart';
import '../../../../application/providers/task_provider.dart';
import '../../../../application/providers/streak_provider.dart';
import '../../../../application/providers/settings_provider.dart';
import '../../../../application/providers/player_provider.dart';
import '../../../../application/services/timezone_service.dart';
import '../../../widgets/common/level_up_snackbar.dart';
import '../../../widgets/task_tile.dart';
import '../../task_form/task_form_sheet.dart';

class TaskSection extends ConsumerWidget {
  final String title;
  final List<Task> tasks;

  const TaskSection({
    super.key,
    required this.title,
    required this.tasks,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${tasks.length}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tasks.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final task = tasks[index];
            return TaskTile(
              task: task,
              onTap: () => _toggleComplete(context, ref, task.id),
              onEdit: () => _showEditForm(context, task),
              onDelete: () => _deleteTask(ref, task.id),
              onDeleteSeries: () => _deleteTaskAndRecurring(ref, task.id),
            );
          },
        ),
      ],
    );
  }

  void _showEditForm(BuildContext context, Task task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TaskFormSheet(
        initialDate: task.scheduledDate,
        taskId: task.id,
      ),
    );
  }

  Future<void> _toggleComplete(
      BuildContext context, WidgetRef ref, String id) async {
    // Captura el estado ANTES del toggle para saber si la transición es
    // completar (suma XP) o desmarcar (resta XP).
    final task = ref.read(tasksProvider).where((t) => t.id == id).firstOrNull;
    if (task == null) return;
    final wasCompleted = task.isCompleted;

    // Se espera a que toggleComplete actualice el estado (refresh() es
    // síncrono después del update en Hive) para que tasksProvider refleje la
    // transición completa→incompleta ANTES del recálculo de racha.
    await ref.read(tasksProvider.notifier).toggleComplete(id);

    // La racha se recalcula SIEMPRE (al completar Y al descompletar, R3b).
    // La fuente de verdad son las tareas completadas (tasksProvider), por lo
    // que el cálculo derivado es simétrico y no depende del orden de marcado
    // (R2a): completar "ayer" después de "hoy" también suma ayer.
    //
    // Usa el instante exacto en la zona configurada (no el valor cacheado
    // del stream) para no depender del último refresco de nowProvider.
    final now = TimezoneService.nowInTimezone(ref.read(settingsProvider).timezone);
    await ref.read(streakProvider.notifier).recalculate(
          tasks: ref.read(tasksProvider),
          now: now,
        );

    // F2 (Nivel de Jugador + XP): complementa a racha/insignias, no las
    // sustituye. Completar suma +10/+15/+20 según prioridad; desmarcar RESTA
    // el mismo XP (simetría anti-exploit) pero el nivel alcanzado NUNCA baja.
    final playerNotifier = ref.read(playerProvider.notifier);
    final int? levelUpLevel;
    if (wasCompleted) {
      await playerNotifier.removeTaskXp(task.priority);
      levelUpLevel = null;
    } else {
      levelUpLevel = await playerNotifier.addTaskXp(task.priority);
      if (levelUpLevel != null && context.mounted) {
        showLevelUpSnackBar(context, levelUpLevel);
      }
    }
  }

  void _deleteTask(WidgetRef ref, String id) {
    ref.read(tasksProvider.notifier).deleteTask(id);
  }

  void _deleteTaskAndRecurring(WidgetRef ref, String id) {
    ref.read(tasksProvider.notifier).deleteTaskAndRecurring(id);
  }
}
