import '../entities/task.dart';

abstract class TaskRepository {
  List<Task> getAll();
  Task? getById(String id);
  Future<void> add(Task task);
  Future<void> update(Task task);
  Future<void> delete(String id);
  List<Task> getByDate(DateTime date);
  List<Task> getByDateRange(DateTime start, DateTime end);
  List<Task> getUncompleted();
}