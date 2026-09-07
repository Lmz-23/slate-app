import 'package:hive_flutter/hive_flutter.dart';
import '../../../domain/entities/task.dart';

class TasksBox {
  static const String _boxName = 'tasks';
  late Box<Task> _box;

  Future<void> init() async {
    _box = await Hive.openBox<Task>(_boxName);
  }

  Box<Task> get box => _box;

  List<Task> getAll() => _box.values.toList();

  Task? get(String id) {
    try {
      return _box.values.firstWhere((task) => task.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> add(Task task) async {
    await _box.put(task.id, task);
  }

  Future<void> update(Task task) async {
    await _box.put(task.id, task);
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  List<Task> getByDate(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return _box.values.where((task) {
      return task.scheduledDate.isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
          task.scheduledDate.isBefore(endOfDay);
    }).toList();
  }

  List<Task> getByDateRange(DateTime start, DateTime end) {
    return _box.values.where((task) {
      return task.scheduledDate.isAfter(start.subtract(const Duration(seconds: 1))) &&
          task.scheduledDate.isBefore(end.add(const Duration(seconds: 1)));
    }).toList();
  }

  List<Task> getUncompleted() {
    return _box.values.where((task) => !task.isCompleted).toList();
  }
}