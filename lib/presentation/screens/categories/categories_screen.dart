import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
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
          ? _buildEmptyState()
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.category_outlined,
            size: 64,
            color: AppColors.textTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Sin categorías',
            style: TextStyle(
              fontSize: 18,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Toca + para crear una categoría',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTile(BuildContext context, WidgetRef ref, Category category) {
    return SlateCard(
      onTap: () => _showCategoryForm(context, ref, category: category),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.fromHex(category.colorHex),
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
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.textTertiary),
            onPressed: () => _deleteCategory(context, ref, category.id),
          ),
        ],
      ),
    );
  }

  void _showCategoryForm(BuildContext context, WidgetRef ref, {Category? category}) {
    final nameController = TextEditingController(text: category?.name ?? '');
    String selectedColor = category?.colorHex ?? AppColors.categoryColors.first.value.toRadixString(16).substring(2);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category == null ? 'Nueva categoría' : 'Editar categoría',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Nombre de categoría',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const Text(
                      'Color',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: AppColors.categoryColors.map((color) {
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
                                  ? Border.all(color: Colors.white, width: 3)
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, color: Colors.white, size: 20)
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
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          ),
                        ),
                        child: Text(
                          category == null ? 'Crear' : 'Guardar',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Eliminar categoría',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          '¿Estás seguro de que quieres eliminar esta categoría?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              ref.read(categoriesProvider.notifier).deleteCategory(id);
              Navigator.pop(context);
            },
            child: const Text(
              'Eliminar',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}