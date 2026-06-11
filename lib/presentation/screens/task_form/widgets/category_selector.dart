import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../domain/entities/category.dart';

class CategorySelector extends StatelessWidget {
  final List<Category> categories;
  final String? selectedId;
  final Function(String?) onChanged;

  const CategorySelector({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Categoría',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _buildChip(null, 'Sin categoría'),
            ...categories.map((cat) => _buildChip(cat.id, cat.name, colorHex: cat.colorHex)),
          ],
        ),
      ],
    );
  }

  Widget _buildChip(String? id, String label, {String? colorHex}) {
    final isSelected = selectedId == id;
    final color = colorHex != null ? AppColors.fromHex(colorHex) : AppColors.textTertiary;

    return GestureDetector(
      onTap: () => onChanged(id),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? Border.all(color: color, width: 1) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (colorHex != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isSelected ? color : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}