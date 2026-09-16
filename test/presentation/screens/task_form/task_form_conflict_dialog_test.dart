import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:slate_app/application/providers/category_provider.dart';
import 'package:slate_app/application/providers/notification_providers.dart';
import 'package:slate_app/application/providers/settings_provider.dart';
import 'package:slate_app/application/providers/task_provider.dart';
import 'package:slate_app/application/services/reminder_manager.dart';
import 'package:slate_app/application/services/reminder_scheduler.dart';
import 'package:slate_app/data/hive/adapters/task_adapter.dart';
import 'package:slate_app/data/hive/adapters/user_settings_adapter.dart';
import 'package:slate_app/data/hive/boxes/categories_box.dart';
import 'package:slate_app/data/hive/boxes/settings_box.dart';
import 'package:slate_app/data/hive/boxes/tasks_box.dart';
import 'package:slate_app/domain/entities/category.dart';
import 'package:slate_app/domain/entities/task.dart';
import 'package:slate_app/domain/enums/recurrence_type.dart';
import 'package:slate_app/domain/enums/task_priority.dart';
import 'package:slate_app/presentation/screens/task_form/task_form_sheet.dart';

/// Fake del contrato de bajo nivel de notificaciones (evita el plugin nativo
/// en `flutter test`, mismo patrón que quest_auto_claim_test.dart).
class _FakeScheduler implements ReminderScheduler {
  @override
  Future<void> init({required String timezone}) async {}

  @override
  Future<bool> canScheduleExactNotifications() async => true;

  @override
  Future<bool> requestExactAlarmsPermission() async => true;

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime fireTime,
  }) async {}

  @override
  Future<void> cancel(int id) async {}
}

/// Doble de [CategoriesBox] SIN Hive real: el formulario solo lee
/// `categoriesProvider` para poblar el selector, ningún test de este archivo
/// ejercita categorías.
class _EmptyCategoriesBox implements CategoriesBox {
  @override
  List<Category> getAll() => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('No debería invocarse en este test');
}

Task _timedTask({
  required String id,
  required DateTime date,
  required int hour,
  required int minute,
  required int durationMinutes,
  String title = 'Tarea existente',
}) {
  return Task(
    id: id,
    title: title,
    scheduledDate: date,
    scheduledTime: DateTime(date.year, date.month, date.day, hour, minute),
    durationMinutes: durationMinutes,
    priority: TaskPriority.normal,
    recurrence: RecurrenceType.none,
    createdAt: date,
  );
}

void main() {
  late Directory tempDir;
  late TasksBox tasksBox;
  late SettingsBox settingsBox;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('slate_task_form_conflict_test');
    Hive.init(tempDir.path);
    Hive.registerAdapter(TaskAdapter());
    Hive.registerAdapter(UserSettingsAdapter());
  });

  setUp(() async {
    tasksBox = TasksBox();
    await tasksBox.init();
    settingsBox = SettingsBox();
    await settingsBox.init();
  });

  tearDown(() async {
    await Hive.close();
    await Hive.deleteBoxFromDisk('tasks');
    await Hive.deleteBoxFromDisk('settings');
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  final day = DateTime(2026, 3, 10);

  /// Monta el formulario EXACTAMENTE como en producción
  /// (`home_screen.dart._showTaskForm`): dentro de un `showModalBottomSheet`,
  /// no como `body` directo de un `Scaffold`. Es necesario para que
  /// `Navigator.pop(context)` (al terminar de guardar) tenga una ruta real que
  /// cerrar — con el form como body directo del Scaffold, `pop()` no tiene
  /// nada que quitar y el sheet queda montado para siempre, dando un falso
  /// negativo en cualquier aserción de "el formulario se cerró al guardar".
  Future<void> pumpForm(WidgetTester tester, {required String taskId}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tasksBoxProvider.overrideWithValue(tasksBox),
          settingsBoxProvider.overrideWithValue(settingsBox),
          categoriesBoxProvider.overrideWithValue(_EmptyCategoriesBox()),
          reminderManagerProvider.overrideWithValue(
            ReminderManager(scheduler: _FakeScheduler()),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => TaskFormSheet(initialDate: day, taskId: taskId),
                  ),
                  child: const Text('abrir formulario'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir formulario'));
    // Anima la apertura del bottom sheet.
    await tester.pumpAndSettle();
    // El formulario precarga la tarea en un `addPostFrameCallback`.
    await tester.pump();
    await tester.pump();
  }

  /// El botón "Guardar" queda fuera del viewport 800x600 del test dentro del
  /// `SingleChildScrollView` del formulario: hay que desplazarlo a la vista
  /// antes de tocarlo o el tap no impacta ningún widget (offset fuera del
  /// árbol de render) y `onPressed` nunca se dispara.
  Future<void> tapGuardar(WidgetTester tester) async {
    final finder = find.widgetWithText(ElevatedButton, 'Guardar');
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
  }

  /// Tras resolver el diálogo (Acortar/Guardar de todos modos), `_saveTask`
  /// continúa con I/O real de Hive antes de cerrar el sheet (`Navigator.pop`).
  /// Un único `pump()` no basta: hay que drenar esa cola de microtasks/IO
  /// real (posible solo dentro de `runAsync`) antes de comprobar el cierre.
  Future<void> settleRealAsync(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await tester.pump();
    }
  }

  /// Escritura Hive real (I/O real): debe correr fuera del reloj falso de
  /// `testWidgets` (mismo patrón que badge_vault_test.dart / task_tile_test.dart).
  Future<void> seed(List<Task> tasks) async {
    for (final t in tasks) {
      await tasksBox.add(t);
    }
  }

  group('TaskFormSheet - diálogo de conflicto de horario', () {
    testWidgets(
        'aparece al guardar si hay solapamiento, y ofrece "Acortar" cuando '
        'canTruncate es true (la existente empieza antes)', (tester) async {
      // Editando "b" (10:00-11:00). "a" (09:00-10:30) empieza antes → puede
      // acortarse a 09:00-10:00.
      final a = _timedTask(id: 'a', date: day, hour: 9, minute: 0, durationMinutes: 90, title: 'Reunión');
      final b = _timedTask(id: 'b', date: day, hour: 10, minute: 0, durationMinutes: 60, title: 'Editando');

      await tester.runAsync(() => seed([a, b]));
      await pumpForm(tester, taskId: 'b');

      await tapGuardar(tester);
      await tester.pump();

      expect(find.text('Conflicto de horario'), findsOneWidget);
      expect(find.textContaining('"Reunión" se solapa'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Acortar "Reunión"'), findsOneWidget);
      expect(find.text('Guardar de todos modos'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
    });

    testWidgets('NO ofrece "Acortar" cuando canTruncate es false (la existente '
        'empieza a la vez o después)', (tester) async {
      // Editando "b" (09:00-10:00). "a" (09:30-10:30) empieza DESPUÉS del
      // borrador → no se puede "acortar" la existente sin destruir su inicio.
      final a = _timedTask(id: 'a', date: day, hour: 9, minute: 30, durationMinutes: 60, title: 'Reunión');
      final b = _timedTask(id: 'b', date: day, hour: 9, minute: 0, durationMinutes: 60, title: 'Editando');

      await tester.runAsync(() => seed([a, b]));
      await pumpForm(tester, taskId: 'b');

      await tapGuardar(tester);
      await tester.pump();

      expect(find.text('Conflicto de horario'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing,
          reason: 'canTruncate es false: no debe existir botón "Acortar"');
      expect(find.text('Guardar de todos modos'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
    });

    testWidgets('"Cancelar" cierra el diálogo y NO guarda (el form sigue abierto)',
        (tester) async {
      final a = _timedTask(id: 'a', date: day, hour: 9, minute: 0, durationMinutes: 90, title: 'Reunión');
      final b = _timedTask(id: 'b', date: day, hour: 10, minute: 0, durationMinutes: 60, title: 'Editando');

      await tester.runAsync(() => seed([a, b]));
      await pumpForm(tester, taskId: 'b');

      await tapGuardar(tester);
      await tester.pump();
      expect(find.text('Conflicto de horario'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pump();

      expect(find.text('Conflicto de horario'), findsNothing);
      // El form sigue montado (no se navegó fuera): el título del campo sigue
      // presente.
      expect(find.byType(TaskFormSheet), findsOneWidget);
    });

    testWidgets('"Guardar de todos modos" cierra el diálogo, guarda sin tocar '
        'la tarea en conflicto y cierra el formulario', (tester) async {
      final a = _timedTask(id: 'a', date: day, hour: 9, minute: 0, durationMinutes: 90, title: 'Reunión');
      final b = _timedTask(id: 'b', date: day, hour: 10, minute: 0, durationMinutes: 60, title: 'Editando');

      await tester.runAsync(() => seed([a, b]));
      await pumpForm(tester, taskId: 'b');

      // TODA la cadena "Guardar" → diálogo → "Guardar de todos modos" →
      // `tasksNotifier.updateTask` (I/O real de Hive) debe correr dentro del
      // MISMO `runAsync`: el guardado es una continuación de la función
      // async disparada por el primer tap, así que si ese primer tap ocurre
      // fuera de `runAsync` la continuación queda atrapada en el reloj falso
      // de `testWidgets` y el `await` a Hive nunca se resuelve (cuelgue).
      await tester.runAsync(() async {
        await tapGuardar(tester);
        await tester.pump();
        expect(find.text('Conflicto de horario'), findsOneWidget);

        await tester.tap(find.text('Guardar de todos modos'));
        await tester.pump();
        await settleRealAsync(tester);
      });
      // El cierre del bottom sheet es una animación (Ticker): dentro de
      // `runAsync` el reloj de test sigue simulado, así que hace falta
      // `pumpAndSettle` FUERA de `runAsync` para avanzarla hasta el final
      // antes de comprobar que el sheet ya no está montado.
      await tester.pumpAndSettle();

      expect(find.text('Conflicto de horario'), findsNothing);
      expect(find.byType(TaskFormSheet), findsNothing,
          reason: '"Guardar de todos modos" debe completar el guardado y cerrar el sheet');

      final existingA = tasksBox.get('a')!;
      expect(existingA.durationMinutes, 90,
          reason: '"Guardar de todos modos" NO debe modificar la tarea en conflicto');
    });

    testWidgets('"Acortar" trunca la tarea existente y permite guardar sin '
        'reabrir el diálogo (el conflicto ya no existe)', (tester) async {
      final a = _timedTask(id: 'a', date: day, hour: 9, minute: 0, durationMinutes: 90, title: 'Reunión');
      final b = _timedTask(id: 'b', date: day, hour: 10, minute: 0, durationMinutes: 60, title: 'Editando');

      await tester.runAsync(() => seed([a, b]));
      await pumpForm(tester, taskId: 'b');

      // Ver comentario en el test anterior: toda la cadena con I/O real debe
      // vivir dentro de un único `runAsync`.
      await tester.runAsync(() async {
        await tapGuardar(tester);
        await tester.pump();
        expect(find.text('Conflicto de horario'), findsOneWidget);

        await tester.tap(find.widgetWithText(FilledButton, 'Acortar "Reunión"'));
        // Trunca (I/O real) y re-consulta el conflicto; con "Reunión"
        // acortada a 09:00-10:00 ya no solapa con "Editando" (10:00-11:00)
        // → el `while(true)` de `_saveTask` guarda directo sin reabrir diálogo.
        await tester.pump();
        await settleRealAsync(tester);
      });
      // Ver comentario en el test anterior sobre la animación de cierre.
      await tester.pumpAndSettle();

      expect(find.text('Conflicto de horario'), findsNothing,
          reason: 'tras acortar, el nuevo rango de "Reunión" ya no solapa con el borrador');
      expect(find.byType(TaskFormSheet), findsNothing,
          reason: 'tras acortar (sin más conflictos) el guardado debe completarse y cerrar el sheet');

      final truncatedA = tasksBox.get('a')!;
      expect(truncatedA.durationMinutes, 60,
          reason: '09:00 a 10:00 (inicio del borrador) = 60 minutos');
    });
  });
}
