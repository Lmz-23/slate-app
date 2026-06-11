import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/category.dart';
import '../../data/hive/boxes/categories_box.dart';
import '../../data/repositories/category_repository_impl.dart';

final categoriesBoxProvider = Provider<CategoriesBox>((ref) {
  throw UnimplementedError('Must be overridden');
});

final categoryRepositoryProvider = Provider<CategoryRepositoryImpl>((ref) {
  return CategoryRepositoryImpl(ref.watch(categoriesBoxProvider));
});

final categoriesProvider = StateNotifierProvider<CategoriesNotifier, List<Category>>((ref) {
  return CategoriesNotifier(ref.watch(categoryRepositoryProvider));
});

class CategoriesNotifier extends StateNotifier<List<Category>> {
  final CategoryRepositoryImpl _repository;
  final _uuid = const Uuid();

  CategoriesNotifier(this._repository) : super(_repository.getAll());

  void refresh() {
    state = _repository.getAll();
  }

  Future<void> addCategory({
    required String name,
    required String colorHex,
  }) async {
    final category = Category(
      id: _uuid.v4(),
      name: name,
      colorHex: colorHex,
      createdAt: DateTime.now(),
    );
    await _repository.add(category);
    refresh();
  }

  Future<void> updateCategory(Category category) async {
    await _repository.update(category);
    refresh();
  }

  Future<void> deleteCategory(String id) async {
    await _repository.delete(id);
    refresh();
  }

  Category? getById(String id) {
    try {
      return state.firstWhere((cat) => cat.id == id);
    } catch (_) {
      return null;
    }
  }
}