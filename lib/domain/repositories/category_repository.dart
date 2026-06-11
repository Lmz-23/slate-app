import '../entities/category.dart';

abstract class CategoryRepository {
  List<Category> getAll();
  Category? getById(String id);
  Future<void> add(Category category);
  Future<void> update(Category category);
  Future<void> delete(String id);
}