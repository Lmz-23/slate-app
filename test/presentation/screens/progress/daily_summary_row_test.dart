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
import 'package:slate_app/presentation/screens/progress/widgets/daily_summary_row.dart';

/// Doble de [TasksBox] SIN Hive real: `DailySummaryRow` solo LEE
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

/// "Hoy" fijo: martes 10 de marzo de 2026 (semana lunes 09 → domingo 15).
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

Future<ProviderContainer> _pumpRow(
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

  // Asegura que `nowProvider.value` esté disponible ANTES de construir
  // `selectedDateProvider` (que lo lee de forma síncrona en su `build`),
  // igual que en `monthly_calendar_test.dart`.
  await container.read(nowProvider.future);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(body: DailySummaryRow()),
      ),
    ),
  );
  await tester.pump();
  return container;
}

void main() {
  group('DailySummaryRow - render básico', () {
    testWidgets('caso borde: sin tareas en toda la semana, renderiza 0 en los 7 días',
        (tester) async {
      await _pumpRow(tester, tasks: []);

      expect(tester.takeException(), isNull);
      expect(find.text('L'), findsOneWidget);
      expect(find.text('D'), findsOneWidget);
      // 7 columnas, cada una en "0" completadas.
      expect(find.text('0'), findsNWidgets(7));
    });

    testWidgets('con datos reales: refleja completadas/total por día de la semana navegada',
        (tester) async {
      // Semana lunes 2026-03-09 → domingo 2026-03-15.
      final monday = DateTime(2026, 3, 9);
      final tuesday = DateTime(2026, 3, 10);

      await _pumpRow(tester, tasks: [
        _task(id: 'a', date: monday, completed: true),
        _task(id: 'b', date: monday, completed: false),
        _task(id: 'c', date: tuesday, completed: true),
      ]);

      expect(tester.takeException(), isNull);
      // Lunes: 1 completada de 2 → "1". Martes (hoy): 1 completada de 1 → "1".
      // El resto de los 5 días sin tareas muestran "0".
      expect(find.text('1'), findsNWidgets(2));
      expect(find.text('0'), findsNWidgets(5));
    });

    testWidgets('tocar un día actualiza selectedDateProvider', (tester) async {
      final container = await _pumpRow(tester, tasks: []);

      final initialSelected = container.read(selectedDateProvider);
      expect(initialSelected, DateTime(2026, 3, 10));

      // Toca la primera columna (Lunes, 09/03) — antes del día seleccionado.
      await tester.tap(find.text('L'));
      await tester.pump();

      final updatedSelected = container.read(selectedDateProvider);
      expect(updatedSelected, DateTime(2026, 3, 9));
    });
  });
}
