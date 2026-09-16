import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:slate_app/application/providers/now_provider.dart';
import 'package:slate_app/application/providers/task_provider.dart';
import 'package:slate_app/core/theme/app_theme.dart';
import 'package:slate_app/data/hive/boxes/tasks_box.dart';
import 'package:slate_app/domain/entities/task.dart';
import 'package:slate_app/domain/enums/recurrence_type.dart';
import 'package:slate_app/domain/enums/task_priority.dart';
import 'package:slate_app/presentation/screens/progress/widgets/weekly_progress_section.dart';

/// Doble de [TasksBox] SIN Hive real: `WeeklyProgressSection` solo LEE
/// `tasksProvider`. Mismo patrón que
/// `test/presentation/screens/home/widgets/daily_progress_card_test.dart`.
class _FixedTasksBox implements TasksBox {
  _FixedTasksBox(this._tasks);
  final List<Task> _tasks;

  @override
  List<Task> getAll() => _tasks;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('No debería invocarse en este test');
}

/// "Hoy" fijo: martes 10 de marzo de 2026.
final _now = DateTime(2026, 3, 10, 12, 0);

Task _task({
  required String id,
  required DateTime date,
  bool completed = false,
}) {
  return Task(
    id: id,
    title: 'Tarea $id',
    scheduledDate: date,
    isCompleted: completed,
    priority: TaskPriority.normal,
    recurrence: RecurrenceType.none,
    createdAt: date,
  );
}

Future<ProviderContainer> _pumpSection(
  WidgetTester tester, {
  required List<Task> tasks,
}) async {
  final container = ProviderContainer(
    overrides: [
      tasksBoxProvider.overrideWithValue(_FixedTasksBox(tasks)),
      nowProvider.overrideWith((ref) => Stream<DateTime>.value(_now)),
    ],
  );
  addTearDown(container.dispose);

  await container.read(nowProvider.future);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(body: WeeklyProgressSection()),
      ),
    ),
  );
  await tester.pump();
  return container;
}

void main() {
  group('WeeklyProgressSection - render básico', () {
    testWidgets('caso borde: sin tareas, "0 de 0 tareas completadas esta semana"',
        (tester) async {
      await _pumpSection(tester, tasks: []);

      expect(tester.takeException(), isNull);
      expect(find.text('0 de 0 tareas completadas esta semana'), findsOneWidget);
    });

    testWidgets('con datos reales: refleja completadas/total de la semana en curso',
        (tester) async {
      // Semana en curso (domingo 2026-03-08 → hoy martes 2026-03-10, según
      // `weeklyProgressProvider`, que arranca en domingo y corta en "ahora").
      final sunday = DateTime(2026, 3, 8);
      final monday = DateTime(2026, 3, 9);
      final tuesday = DateTime(2026, 3, 10);

      await _pumpSection(tester, tasks: [
        _task(id: 'a', date: sunday, completed: true),
        _task(id: 'b', date: monday, completed: true),
        _task(id: 'c', date: monday, completed: false),
        _task(id: 'd', date: tuesday, completed: false),
      ]);

      expect(tester.takeException(), isNull);
      expect(find.text('2 de 4 tareas completadas esta semana'), findsOneWidget);
    });

    testWidgets('la navegación de semana (chevron) mueve selectedDateProvider ±7 días',
        (tester) async {
      final container = await _pumpSection(tester, tasks: []);
      final initialSelected = container.read(selectedDateProvider);

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();

      expect(
        container.read(selectedDateProvider),
        initialSelected.subtract(const Duration(days: 7)),
      );

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();

      expect(
        container.read(selectedDateProvider),
        initialSelected.add(const Duration(days: 7)),
      );
    });
  });
}
