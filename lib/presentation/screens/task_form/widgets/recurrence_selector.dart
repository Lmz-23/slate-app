import 'package:flutter/material.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/slate_theme_context.dart';
import '../../../../domain/enums/recurrence_type.dart';

/// Selector de recurrencia (sistema-visual-fase3.md §4): mismo tratamiento
/// visual que el selector de prioridad (fondo `surfaceAlt` inactivo, `accent`
/// al 12% + borde `accent` activo), sin punto de color.
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
    final slate = context.slate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Repetir',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 12,
            color: slate.textSecondary,
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
                  color: isSelected ? slate.accent.withValues(alpha: 0.12) : slate.surfaceAlt,
                  borderRadius: BorderRadius.circular(20),
                  border: isSelected ? Border.all(color: slate.accent, width: 1.5) : null,
                ),
                child: Text(
                  type.displayName,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    color: isSelected ? slate.accent : slate.textSecondary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (selected == RecurrenceType.specificDays) ...[
          const SizedBox(height: AppSpacing.md),
          _buildDaysSelector(context),
        ],
      ],
    );
  }

  Widget _buildDaysSelector(BuildContext context) {
    final slate = context.slate;
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
              color: isSelected ? slate.accent : slate.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                days[index],
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? slate.onAccent : slate.textSecondary,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
