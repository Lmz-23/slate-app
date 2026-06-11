import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../domain/enums/task_priority.dart';

class PrioritySelector extends StatelessWidget {
  final TaskPriority selected;
  final Function(TaskPriority) onChanged;

  const PrioritySelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Prioridad',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: TaskPriority.values.map((priority) {
            final isSelected = priority == selected;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(priority),
                child: Container(
                  margin: const EdgeInsets.only(right: AppSpacing.sm),
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? _getColor(priority).withValues(alpha: 0.2) : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    border: isSelected ? Border.all(color: _getColor(priority), width: 1) : null,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getColor(priority),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        priority.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? _getColor(priority) : AppColors.textSecondary,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Color _getColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return AppColors.error;
      case TaskPriority.medium:
        return AppColors.warning;
      case TaskPriority.normal:
        return AppColors.primary;
    }
  }
}