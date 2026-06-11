import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../domain/entities/task.dart';
import '../../../../application/providers/task_provider.dart';
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
              onTap: () => _showEditForm(context, task),
              onComplete: () => _toggleComplete(ref, task.id),
              onDelete: () => _deleteTask(ref, task.id),
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

  void _toggleComplete(WidgetRef ref, String id) {
    ref.read(tasksProvider.notifier).toggleComplete(id);
  }

  void _deleteTask(WidgetRef ref, String id) {
    ref.read(tasksProvider.notifier).deleteTask(id);
  }
}