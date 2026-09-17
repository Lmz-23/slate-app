import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/slate_shapes.dart';
import '../../../core/theme/slate_theme_context.dart';
import '../../../core/theme/tokens/slate_palette.dart';
import '../../../core/utils/color_utils.dart';
import '../../../domain/entities/category.dart';
import '../../../application/providers/category_provider.dart';
import '../../widgets/common/slate_card.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorías'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCategoryForm(context, ref),
          ),
        ],
      ),
      body: categories.isEmpty
          ? _buildEmptyState(context)
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final category = categories[index];
                return _buildCategoryTile(context, ref, category);
              },
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final slate = context.slate;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.category_outlined,
            size: 40,
            color: slate.textTertiary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Sin categorías',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: slate.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Toca + para crear una categoría',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12.5,
              color: slate.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTile(BuildContext context, WidgetRef ref, Category category) {
    final slate = context.slate;
    return SlateCard(
      onTap: () => _showCategoryForm(context, ref, category: category),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ColorUtils.fromHex(category.colorHex),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.folder,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              category.name,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: slate.textPrimary,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: slate.textTertiary),
            onPressed: () => _deleteCategory(context, ref, category.id),
          ),
        ],
      ),
    );
  }

  void _showCategoryForm(BuildContext context, WidgetRef ref, {Category? category}) {
    final nameController = TextEditingController(text: category?.name ?? '');
    // Paleta curada de categorías NUEVAS (Decisión A5, sistema-visual-fase3.md
    // §5): las categorías existentes conservan su colorHex propio sin cambio.
    String selectedColor = category?.colorHex ??
        SlatePalette.categoryPalette.first.value.toRadixString(16).substring(2);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final slate = context.slate;
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: slate.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category == null ? 'Nueva categoría' : 'Editar categoría',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: slate.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      style: TextStyle(fontFamily: 'Nunito', color: slate.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Nombre de categoría',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Color',
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
                      children: SlatePalette.categoryPalette.map((color) {
                        final colorHex = color.value.toRadixString(16).substring(2);
                        final isSelected = selectedColor == colorHex;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedColor = colorHex;
                            });
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(10),
                              border: isSelected
                                  ? Border.all(color: slate.onAccent, width: 3)
                                  : null,
                            ),
                            child: isSelected
                                ? Icon(Icons.check, color: slate.onAccent, size: 20)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (nameController.text.isNotEmpty) {
                            if (category == null) {
                              ref.read(categoriesProvider.notifier).addCategory(
                                    name: nameController.text,
                                    colorHex: '#$selectedColor',
                                  );
                            } else {
                              ref.read(categoriesProvider.notifier).updateCategory(
                                    category.copyWith(
                                      name: nameController.text,
                                      colorHex: '#$selectedColor',
                                    ),
                                  );
                            }
                            Navigator.pop(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: slate.accent,
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(SlateShapes.radiusSmall),
                          ),
                        ),
                        child: Text(
                          category == null ? 'Crear' : 'Guardar',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: slate.onAccent,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _deleteCategory(BuildContext context, WidgetRef ref, String id) {
    final slate = context.slate;
    showDialog(
      context: context,
      barrierColor: slate.background.withValues(alpha: 0.6),
      builder: (context) => AlertDialog(
        backgroundColor: slate.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SlateShapes.radiusLarge),
        ),
        title: Text(
          '¿Eliminar categoría?',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: slate.textPrimary,
          ),
        ),
        content: Text(
          '¿Estás seguro de que quieres eliminar esta categoría?',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 13,
            color: slate.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: slate.textSecondary)),
          ),
          FilledButton(
            onPressed: () {
              ref.read(categoriesProvider.notifier).deleteCategory(id);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: slate.danger,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(SlateShapes.radiusSmall),
              ),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
