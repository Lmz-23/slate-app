import 'package:flutter/material.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/slate_colors.dart';
import '../../../../core/theme/slate_shapes.dart';
import '../../../../core/theme/slate_theme_context.dart';
import '../../../../domain/enums/task_priority.dart';

/// Selector de prioridad (sistema-visual-fase3.md §4): 3 segmentos en fila,
/// tipo "pill group", altura 40, radio 14. Prioridad normal no lleva punto
/// (ausencia, no color neutro) — mismo criterio que el punto único del tile
/// (§8).
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
    final slate = context.slate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Prioridad',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 12,
            color: slate.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: TaskPriority.values.map((priority) {
            final isSelected = priority == selected;
            final dotColor = _dotColor(slate, priority);
            final isLast = priority == TaskPriority.values.last;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(priority),
                child: Container(
                  height: 40,
                  margin: EdgeInsets.only(right: isLast ? 0 : AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: isSelected ? slate.accent.withValues(alpha: 0.12) : slate.surfaceAlt,
                    borderRadius: BorderRadius.circular(SlateShapes.radiusSmall),
                    border: isSelected ? Border.all(color: slate.accent, width: 1.5) : null,
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (dotColor != null) ...[
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: dotColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        priority.displayName,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 13,
                          color: isSelected ? (dotColor ?? slate.textPrimary) : slate.textSecondary,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
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

  /// `null` para prioridad normal: no se pinta un punto neutro (§8).
  Color? _dotColor(SlateColors slate, TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return slate.priorityHigh;
      case TaskPriority.medium:
        return slate.priorityMedium;
      case TaskPriority.normal:
        return null;
    }
  }
}
