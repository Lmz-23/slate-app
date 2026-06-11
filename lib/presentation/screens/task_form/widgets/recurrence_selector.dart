import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../domain/enums/recurrence_type.dart';

class RecurrenceSelector extends StatelessWidget {
  final RecurrenceType selected;
  final List<int> selectedDays;
  final Function(RecurrenceType, List<int>?) onChanged;

  const RecurrenceSelector({
    super.key,
    required this.selected,
    required this.selectedDays,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Repetir',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: RecurrenceType.values.map((type) {
            final isSelected = type == selected;
            return GestureDetector(
              onTap: () => onChanged(type, type == RecurrenceType.specificDays ? [1, 2, 3, 4, 5] : null),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary.withValues(alpha: 0.2) : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(20),
                  border: isSelected ? Border.all(color: AppColors.primary, width: 1) : null,
                ),
                child: Text(
                  type.displayName,
                  style: TextStyle(
                    fontSize: 13,
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (selected == RecurrenceType.specificDays) ...[
          const SizedBox(height: AppSpacing.md),
          _buildDaysSelector(),
        ],
      ],
    );
  }

  Widget _buildDaysSelector() {
    const days = ['D', 'L', 'M', 'X', 'J', 'V', 'S'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(7, (index) {
        final isSelected = selectedDays.contains(index);
        return GestureDetector(
          onTap: () {
            final newDays = List<int>.from(selectedDays);
            if (isSelected) {
              newDays.remove(index);
            } else {
              newDays.add(index);
            }
            onChanged(selected, newDays);
          },
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : AppColors.surfaceLight,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                days[index],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}