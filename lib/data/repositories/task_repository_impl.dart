import '../../domain/entities/task.dart';
import '../../domain/repositories/task_repository.dart';
import '../hive/boxes/tasks_box.dart';

class TaskRepositoryImpl implements TaskRepository {
  final TasksBox _tasksBox;

  TaskRepositoryImpl(this._tasksBox);

  @override
  List<Task> getAll() => _tasksBox.getAll();

  @override
  Task? getById(String id) => _tasksBox.get(id);

  @override
  Future<void> add(Task task) => _tasksBox.add(task);

  @override
  Future<void> update(Task task) => _tasksBox.update(task);

  @override
  Future<void> delete(String id) => _tasksBox.delete(id);

  @override
  List<Task> getByDate(DateTime date) => _tasksBox.getByDate(date);

  @override
  List<Task> getByDateRange(DateTime start, DateTime end) => _tasksBox.getByDateRange(start, end);

  @override
  List<Task> getUncompleted() => _tasksBox.getUncompleted();
}