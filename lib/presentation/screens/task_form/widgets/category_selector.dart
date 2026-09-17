import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/slate_theme_context.dart';
import '../../../../core/utils/color_utils.dart';
import '../../../../domain/entities/category.dart';

/// Selector de categoría (sistema-visual-fase3.md §4): fila de chips (mini
/// tile) altura 36, radio 18. Activo: fondo `surfaceAlt` + borde 1.5 del
/// color PROPIO de la categoría (no `accent` genérico).
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
    final slate = context.slate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Categoría',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 12,
            color: slate.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildChip(context, null, 'Sin categoría'),
              const SizedBox(width: AppSpacing.sm),
              ...categories.expand((cat) => [
                    _buildChip(context, cat.id, cat.name, colorHex: cat.colorHex),
                    const SizedBox(width: AppSpacing.sm),
                  ]),
              _buildAddChip(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChip(BuildContext context, String? id, String label, {String? colorHex}) {
    final slate = context.slate;
    final isSelected = selectedId == id;
    final color = colorHex != null ? ColorUtils.fromHex(colorHex) : slate.textTertiary;

    return GestureDetector(
      onTap: () => onChanged(id),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected ? slate.surfaceAlt : slate.surfaceAlt.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(18),
          border: isSelected ? Border.all(color: color, width: 1.5) : null,
        ),
        alignment: Alignment.center,
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
                fontFamily: 'Nunito',
                fontSize: 13,
                color: isSelected ? color : slate.textSecondary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Último chip del selector: abre la gestión de categorías (§4).
  Widget _buildAddChip(BuildContext context) {
    final slate = context.slate;
    return GestureDetector(
      onTap: () => context.push('/categories'),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: slate.surfaceAlt.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 14, color: slate.accent),
            const SizedBox(width: 4),
            Text(
              'Nueva categoría',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: slate.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
