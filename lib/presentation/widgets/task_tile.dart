import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/enums/task_priority.dart';
import '../../../application/providers/task_provider.dart';
import '../../../application/providers/category_provider.dart';
import '../../../core/extensions/datetime_extensions.dart';
import 'common/slate_card.dart';

class TaskTile extends ConsumerWidget {
  final Task task;
  final VoidCallback? onTap;
  final VoidCallback? onComplete;
  final VoidCallback? onDelete;

  const TaskTile({
    super.key,
    required this.task,
    this.onTap,
    this.onComplete,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final category = task.categoryId != null
        ? categories.where((c) => c.id == task.categoryId).firstOrNull
        : null;

    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete?.call(),
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
        onTap: onTap,
        child: Row(
          children: [
            GestureDetector(
              onTap: onComplete,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: task.isCompleted
                      ? AppColors.success
                      : Colors.transparent,
                  border: Border.all(
                    color: task.isCompleted
                        ? AppColors.success
                        : AppColors.textTertiary,
                    width: 2,
                  ),
                ),
                child: task.isCompleted
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            ),
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
                          Icon(
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
                ],
              ),
            ),
            _buildPriorityIndicator(),
          ],
        ),
      ),
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
}