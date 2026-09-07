import 'package:hive_flutter/hive_flutter.dart';
import '../../../domain/entities/category.dart';

class CategoriesBox {
  static const String _boxName = 'categories';
  late Box<Category> _box;

  Future<void> init() async {
    _box = await Hive.openBox<Category>(_boxName);
  }

  Box<Category> get box => _box;

  List<Category> getAll() => _box.values.toList();

  Category? get(String id) {
    try {
      return _box.values.firstWhere((cat) => cat.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> add(Category category) async {
    await _box.put(category.id, category);
  }

  Future<void> update(Category category) async {
    await _box.put(category.id, category);
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }
}