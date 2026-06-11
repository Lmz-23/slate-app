import 'package:home_widget/home_widget.dart';
import '../../domain/entities/task.dart';

class WidgetService {
  static const String _appGroupId = 'group.com.slate.slate_app';
  static const String _androidWidgetName = 'SlateWidgetProvider';

  Future<void> init() async {
    await HomeWidget.setAppGroupId(_appGroupId);
  }

  Future<void> updateWidget(List<Task> todayTasks) async {
    final completed = todayTasks.where((t) => t.isCompleted).length;
    final total = todayTasks.length;

    await HomeWidget.saveWidgetData<String>('tasks_summary', '$completed/$total');
    await HomeWidget.saveWidgetData<String>('last_update', DateTime.now().toIso8601String());

    await HomeWidget.updateWidget(
      name: _androidWidgetName,
      androidName: _androidWidgetName,
    );
  }

  Future<void> clearWidget() async {
    await HomeWidget.saveWidgetData<String>('tasks_summary', '0/0');
    await HomeWidget.updateWidget(
      name: _androidWidgetName,
      androidName: _androidWidgetName,
    );
  }
}