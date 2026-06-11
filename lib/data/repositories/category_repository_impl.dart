import '../../domain/entities/category.dart';
import '../../domain/repositories/category_repository.dart';
import '../hive/boxes/categories_box.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  final CategoriesBox _categoriesBox;

  CategoryRepositoryImpl(this._categoriesBox);

  @override
  List<Category> getAll() => _categoriesBox.getAll();

  @override
  Category? getById(String id) => _categoriesBox.get(id);

  @override
  Future<void> add(Category category) => _categoriesBox.add(category);

  @override
  Future<void> update(Category category) => _categoriesBox.update(category);

  @override
  Future<void> delete(String id) => _categoriesBox.delete(id);
}