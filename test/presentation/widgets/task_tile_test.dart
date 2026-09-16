import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:slate_app/application/providers/task_provider.dart';
import 'package:slate_app/core/theme/app_theme.dart';
import 'package:slate_app/core/theme/slate_colors.dart';
import 'package:slate_app/data/hive/adapters/task_adapter.dart';
import 'package:slate_app/data/hive/boxes/tasks_box.dart';
import 'package:slate_app/domain/entities/task.dart';
import 'package:slate_app/domain/enums/recurrence_type.dart';
import 'package:slate_app/domain/enums/task_priority.dart';
import 'package:slate_app/presentation/widgets/task_tile.dart';

Task _task({
  String id = 't1',
  String title = 'Tarea de prueba',
  TaskPriority priority = TaskPriority.normal,
  DateTime? scheduledTime,
  int? durationMinutes,
  bool isCompleted = false,
  String? parentTaskId,
  bool isSubtask = false,
}) {
  final date = DateTime(2026, 3, 10);
  return Task(
    id: id,
    title: title,
    scheduledDate: date,
    scheduledTime: scheduledTime,
    durationMinutes: durationMinutes,
    priority: priority,
    recurrence: RecurrenceType.none,
    isCompleted: isCompleted,
    parentTaskId: parentTaskId,
    isSubtask: isSubtask,
    createdAt: date,
  );
}

/// Busca el `Container` de 7x7 que codifica el punto de prioridad.
Finder _priorityDotFinder() {
  return find.byWidgetPredicate((w) {
    if (w is! Container) return false;
    final decoration = w.decoration;
    return decoration is BoxDecoration &&
        decoration.shape == BoxShape.circle &&
        w.constraints?.maxWidth == 7 &&
        w.constraints?.maxHeight == 7;
  });
}

void main() {
  late Directory tempDir;
  late TasksBox tasksBox;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('slate_task_tile_test');
    Hive.init(tempDir.path);
    Hive.registerAdapter(TaskAdapter());
  });

  setUp(() async {
    tasksBox = TasksBox();
    await tasksBox.init();
  });

  tearDown(() async {
    await Hive.close();
    await Hive.deleteBoxFromDisk('tasks');
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  Future<void> pumpTile(
    WidgetTester tester, {
    required Task task,
    List<Task>? allTasks,
    VoidCallback? onTap,
    VoidCallback? onEdit,
  }) async {
    // La escritura en Hive es I/O real: debe ejecutarse fuera del reloj falso
    // de `testWidgets` (mismo patrón que badge_vault_test.dart), o el test
    // cuelga indefinidamente esperando un Future que el zone de FakeAsync
    // nunca completa.
    await tester.runAsync(() async {
      for (final t in allTasks ?? [task]) {
        await tasksBox.add(t);
      }
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tasksBoxProvider.overrideWithValue(tasksBox),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: TaskTile(task: task, onTap: onTap, onEdit: onEdit),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('TaskTile - punto de prioridad', () {
    testWidgets('prioridad normal no muestra punto', (tester) async {
      await pumpTile(tester, task: _task(priority: TaskPriority.normal));
      expect(_priorityDotFinder(), findsNothing);
    });

    testWidgets('prioridad alta muestra punto del color priorityHigh', (tester) async {
      final task = _task(priority: TaskPriority.high);
      await pumpTile(tester, task: task);

      expect(_priorityDotFinder(), findsOneWidget);
      final container = tester.widget<Container>(_priorityDotFinder());
      final decoration = container.decoration as BoxDecoration;
      final context = tester.element(find.byType(TaskTile));
      expect(decoration.color, SlateColors.of(context).priorityHigh);
    });

    testWidgets('prioridad media muestra punto del color priorityMedium', (tester) async {
      final task = _task(priority: TaskPriority.medium);
      await pumpTile(tester, task: task);

      expect(_priorityDotFinder(), findsOneWidget);
      final container = tester.widget<Container>(_priorityDotFinder());
      final decoration = container.decoration as BoxDecoration;
      final context = tester.element(find.byType(TaskTile));
      expect(decoration.color, SlateColors.of(context).priorityMedium);
    });
  });

  group('TaskTile - etiqueta de horario', () {
    testWidgets('con duración conocida muestra rango "inicio–fin"', (tester) async {
      final task = _task(
        scheduledTime: DateTime(2026, 3, 10, 14, 30),
        durationMinutes: 90,
      );
      await pumpTile(tester, task: task);

      expect(find.text('14:30–16:00'), findsOneWidget);
    });

    testWidgets('sin duración conocida muestra solo la hora simple', (tester) async {
      final task = _task(
        scheduledTime: DateTime(2026, 3, 10, 9, 0),
        durationMinutes: null,
      );
      await pumpTile(tester, task: task);

      expect(find.text('09:00'), findsOneWidget);
      expect(find.textContaining('–'), findsNothing);
    });
  });

  group('TaskTile - gestos', () {
    testWidgets('el long-press dispara onEdit, no onTap', (tester) async {
      var editCalled = false;
      var tapCalled = false;
      final task = _task();
      await pumpTile(
        tester,
        task: task,
        onEdit: () => editCalled = true,
        onTap: () => tapCalled = true,
      );

      await tester.longPress(find.byType(TaskTile));
      await tester.pump();

      expect(editCalled, isTrue);
      expect(tapCalled, isFalse);
    });

    testWidgets('el toque corto dispara onTap, no onEdit', (tester) async {
      var editCalled = false;
      var tapCalled = false;
      final task = _task();
      await pumpTile(
        tester,
        task: task,
        onEdit: () => editCalled = true,
        onTap: () => tapCalled = true,
      );

      await tester.tap(find.byType(TaskTile));
      await tester.pump();

      expect(tapCalled, isTrue);
      expect(editCalled, isFalse);
    });

    testWidgets('no existe ningún icono more_horiz (retirado del diseño)', (tester) async {
      await pumpTile(tester, task: _task());
      expect(find.byIcon(Icons.more_horiz), findsNothing);
    });
  });
}
