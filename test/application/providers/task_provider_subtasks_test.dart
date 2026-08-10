import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:slate_app/application/providers/notification_providers.dart';
import 'package:slate_app/application/providers/now_provider.dart';
import 'package:slate_app/application/providers/player_provider.dart';
import 'package:slate_app/application/providers/settings_provider.dart';
import 'package:slate_app/application/providers/task_provider.dart';
import 'package:slate_app/application/services/reminder_manager.dart';
import 'package:slate_app/application/services/reminder_scheduler.dart';
import 'package:slate_app/data/hive/adapters/player_profile_adapter.dart';
import 'package:slate_app/data/hive/adapters/task_adapter.dart';
import 'package:slate_app/data/hive/adapters/user_settings_adapter.dart';
import 'package:slate_app/data/hive/boxes/player_progress_box.dart';
import 'package:slate_app/data/hive/boxes/settings_box.dart';
import 'package:slate_app/data/hive/boxes/tasks_box.dart';
import 'package:slate_app/domain/entities/task.dart';
import 'package:slate_app/domain/enums/task_priority.dart';

/// Fake del contrato de bajo nivel (evita el plugin nativo en `flutter test`).
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

void main() {
  late Directory tempDir;
  late TasksBox tasksBox;
  late PlayerProgressBox playerBox;
  late SettingsBox settingsBox;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('slate_subtasks_test');
    Hive.init(tempDir.path);
    Hive.registerAdapter(TaskAdapter());
    Hive.registerAdapter(PlayerProfileAdapter());
    Hive.registerAdapter(UserSettingsAdapter());
  });

  setUp(() async {
    tasksBox = TasksBox();
    await tasksBox.init();
    playerBox = PlayerProgressBox();
    await playerBox.init();
    settingsBox = SettingsBox();
    await settingsBox.init();
  });

  tearDown(() async {
    await Hive.close();
    await Hive.deleteBoxFromDisk('tasks');
    await Hive.deleteBoxFromDisk('player_progress');
    await Hive.deleteBoxFromDisk('settings');
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  ProviderContainer createContainer() => ProviderContainer(
        overrides: [
          tasksBoxProvider.overrideWithValue(tasksBox),
          playerProgressBoxProvider.overrideWithValue(playerBox),
          settingsBoxProvider.overrideWithValue(settingsBox),
          // Reloj inyectado y determinista: `selectedDateProvider` y la
          // visibilidad del día derivan de `nowProvider`.
          nowProvider.overrideWith(
            (ref) => Stream<DateTime>.value(DateTime(2026, 8, 10, 9, 0)),
          ),
          reminderManagerProvider.overrideWithValue(
            ReminderManager(scheduler: _FakeScheduler()),
          ),
        ],
      );

  /// Siembra la tarea principal y sus subtareas ANTES de construir el notifier
  /// (patrón robusto: el estado inicial del provider debe ver los datos).
  Future<void> seed({
    String mainId = 'main',
    TaskPriority priority = TaskPriority.normal,
    List<String>? subtaskIds,
  }) async {
    await tasksBox.add(Task(
      id: mainId,
      title: 'Misión principal',
      scheduledDate: DateTime(2026, 8, 10),
      priority: priority,
      createdAt: DateTime(2026, 8, 10),
    ));
    for (final id in subtaskIds ?? const <String>[]) {
      await tasksBox.add(Task(
        id: id,
        title: 'Subtarea $id',
        scheduledDate: DateTime(2026, 8, 10),
        createdAt: DateTime(2026, 8, 10),
        parentTaskId: mainId,
        isSubtask: true,
      ));
    }
  }

  int xp() => playerBox.getProfile().totalXp;

  Task? byId(ProviderContainer container, String id) =>
      container.read(tasksProvider).where((t) => t.id == id).firstOrNull;

  group('F4 subtareas - XP individual (+2/-2)', () {
    test('marcar una subtarea EXPLÍCITAMENTE da +2 y desmarcarla resta -2',
        () async {
      await seed(subtaskIds: ['s1']);
      final container = createContainer();
      addTearDown(container.dispose);
      final notifier = container.read(tasksProvider.notifier);

      final levelUp = await notifier.toggleComplete('s1');
      expect(levelUp, isNull, reason: '2 XP no cruza el umbral del nivel 2');
      expect(xp(), 2);
      expect(byId(container, 's1')!.isCompleted, isTrue);
      expect(byId(container, 's1')!.subtaskXpGranted, isTrue);

      await notifier.toggleComplete('s1');
      expect(xp(), 0, reason: 'simetría anti-exploit');
      expect(byId(container, 's1')!.isCompleted, isFalse);
      expect(byId(container, 's1')!.subtaskXpGranted, isFalse);
    });

    test('la principal NO recibe el XP por prioridad al marcar una subtarea',
        () async {
      await seed(priority: TaskPriority.high, subtaskIds: ['s1']);
      final container = createContainer();
      addTearDown(container.dispose);

      await container.read(tasksProvider.notifier).toggleComplete('s1');

      expect(xp(), 2,
          reason: 'solo +2 de la subtarea; la principal sigue sin marcarse');
      expect(byId(container, 'main')!.isCompleted, isFalse);
    });

    test('50 subtareas = 100 XP: cruzan al nivel 2 y notifican una sola vez',
        () async {
      await seed(
        subtaskIds: List.generate(50, (i) => 's$i'),
      );
      final container = createContainer();
      addTearDown(container.dispose);
      final notifier = container.read(tasksProvider.notifier);

      int? lastLevelUp;
      for (var i = 0; i < 50; i++) {
        lastLevelUp = await notifier.toggleComplete('s$i');
      }

      expect(xp(), 100);
      expect(playerBox.getProfile().level, 2);
      expect(lastLevelUp, 2,
          reason: 'la 50.ª subtarea cruza el umbral del nivel 2');
      expect(playerBox.getProfile().shownLevelUps, {2});
    });
  });

  group('F4 subtareas - arrastre de la principal', () {
    test('marcar la principal arrastra las subtareas SIN XP individual (+XP '
        'por prioridad)', () async {
      await seed(priority: TaskPriority.high, subtaskIds: ['s1', 's2']);
      final container = createContainer();
      addTearDown(container.dispose);
      final notifier = container.read(tasksProvider.notifier);

      final levelUp = await notifier.toggleComplete('main');

      expect(xp(), 20, reason: 'solo el XP de la principal (no +2 por sub)');
      expect(levelUp, isNull, reason: '20 XP no cruza el umbral');
      expect(byId(container, 'main')!.isCompleted, isTrue);
      expect(byId(container, 's1')!.isCompleted, isTrue);
      expect(byId(container, 's2')!.isCompleted, isTrue);
      expect(byId(container, 's1')!.subtaskXpGranted, isFalse,
          reason: 'las arrastradas NO reciben XP');
      expect(byId(container, 's2')!.subtaskXpGranted, isFalse);
    });

    test('desmarcar la principal revierte el arrastre y RESTA el XP de la '
        'principal', () async {
      await seed(priority: TaskPriority.high, subtaskIds: ['s1', 's2']);
      final container = createContainer();
      addTearDown(container.dispose);
      final notifier = container.read(tasksProvider.notifier);

      await notifier.toggleComplete('main');
      expect(xp(), 20);

      await notifier.toggleComplete('main');

      expect(xp(), 0);
      expect(byId(container, 'main')!.isCompleted, isFalse);
      expect(byId(container, 's1')!.isCompleted, isFalse);
      expect(byId(container, 's2')!.isCompleted, isFalse);
      expect(byId(container, 's1')!.subtaskXpGranted, isFalse);
    });
  });

  group('F4 subtareas - simetría anti-exploit', () {
    test('sub explícita + arrastre + revertido: el XP se conserva (sin farm)',
        () async {
      await seed(priority: TaskPriority.normal, subtaskIds: ['s1', 's2']);
      final container = createContainer();
      addTearDown(container.dispose);
      final notifier = container.read(tasksProvider.notifier);

      await notifier.toggleComplete('s1'); // +2 (explícita)
      expect(xp(), 2);

      await notifier.toggleComplete('main'); // +10, arrastra s1/s2
      expect(xp(), 12);

      await notifier.toggleComplete('main'); // -10, revierte; s1 pierde su +2
      expect(xp(), 0);
      expect(byId(container, 's1')!.isCompleted, isFalse);
      expect(byId(container, 's1')!.subtaskXpGranted, isFalse);

      // Repetir el ciclo NO genera XP extra: la principal da su prioridad al
      // marcar y la resta al desmarcar; las arrastradas nunca dan +2.
      await notifier.toggleComplete('main');
      expect(xp(), 10);
      await notifier.toggleComplete('main');
      expect(xp(), 0);
    });

    test('revertir un arrastre NO resta XP de subtareas que nunca recibieron '
        '+2 (evita penalizar el arrastre)', () async {
      await seed(priority: TaskPriority.high, subtaskIds: ['s1']);
      final container = createContainer();
      addTearDown(container.dispose);
      final notifier = container.read(tasksProvider.notifier);

      await notifier.toggleComplete('main'); // arrastra s1 SIN +2
      expect(xp(), 20);
      expect(byId(container, 's1')!.subtaskXpGranted, isFalse);

      await notifier.toggleComplete('main'); // revertido: s1 no tiene XP que restar
      expect(xp(), 0,
          reason: 'el revertido resta solo el XP de la principal (-20)');
    });

    test('desmarcar una subtarea arrastrada directamente no resta XP no '
        'ganado', () async {
      await seed(priority: TaskPriority.high, subtaskIds: ['s1']);
      final container = createContainer();
      addTearDown(container.dispose);
      final notifier = container.read(tasksProvider.notifier);

      await notifier.toggleComplete('main'); // arrastra s1 SIN +2
      expect(xp(), 20);

      await notifier.toggleComplete('s1'); // desmarcar la arrastrada
      expect(xp(), 20,
          reason: 's1 nunca tuvo XP concedido, no se resta nada');
      expect(byId(container, 's1')!.isCompleted, isFalse);
    });
  });

  group('F4 subtareas - persistencia', () {
    test('el estado (completada + subtaskXpGranted) y el XP sobreviven a un '
        'reinicio', () async {
      await seed(priority: TaskPriority.high, subtaskIds: ['s1', 's2']);
      final first = createContainer();
      final notifier = first.read(tasksProvider.notifier);
      await notifier.toggleComplete('s1'); // +2 explícita
      await notifier.toggleComplete('main'); // +20, arrastra s2
      expect(xp(), 22);
      first.dispose();

      // "Reinicio": un contenedor nuevo lee las mismas cajas.
      final second = createContainer();
      addTearDown(second.dispose);

      expect(xp(), 22, reason: 'el XP persiste en player_progress');
      expect(byId(second, 'main')!.isCompleted, isTrue);
      expect(byId(second, 's1')!.isCompleted, isTrue);
      expect(byId(second, 's1')!.subtaskXpGranted, isTrue,
          reason: 's1 se marcó explícitamente (+2)');
      expect(byId(second, 's2')!.isCompleted, isTrue);
      expect(byId(second, 's2')!.subtaskXpGranted, isFalse,
          reason: 's2 se arrastró sin XP');

      // El revertido posterior también respeta la marca persistida.
      await second.read(tasksProvider.notifier).toggleComplete('main');
      expect(xp(), 0,
          reason: '-20 principal y -2 de s1 (concedido); s2 no resta nada');
      expect(byId(second, 's1')!.subtaskXpGranted, isFalse);
      expect(byId(second, 's2')!.subtaskXpGranted, isFalse);
    });

    test('borrar la principal elimina también sus subtareas (sin huérfanas)',
        () async {
      await seed(subtaskIds: ['s1', 's2']);
      final container = createContainer();
      addTearDown(container.dispose);

      await container.read(tasksProvider.notifier).deleteTask('main');

      expect(container.read(tasksProvider), isEmpty);
      expect(tasksBox.get('s1'), isNull);
      expect(tasksBox.get('s2'), isNull);
    });
  });

  group('H1 - home: las subtareas NO aparecen como tarjetas sueltas', () {
    test('tasksBySelectedDateProvider excluye subtareas y mantiene las '
        'principales del día', () async {
      await seed(mainId: 'main', subtaskIds: ['s1', 's2']);
      final container = createContainer();
      addTearDown(container.dispose);

      final dayTasks = container.read(tasksBySelectedDateProvider);

      expect(dayTasks.map((t) => t.id), ['main'],
          reason: 'solo la principal; las subtareas van anidadas en TaskTile');
      expect(dayTasks.any((t) => t.isSubtask), isFalse);

      // Las subtareas siguen presentes en tasksProvider (no se borran): solo
      // la lista del día las excluye.
      final all = container.read(tasksProvider);
      expect(all.where((t) => t.isSubtask), hasLength(2));
    });

    test('la sección "Sin horario" muestra solo la principal (badge no '
        'inflado por subtareas)', () async {
      await seed(mainId: 'main', subtaskIds: ['s1', 's2']);
      final container = createContainer();
      addTearDown(container.dispose);

      final unscheduled = container.read(unscheduledTasksProvider);
      expect(unscheduled.map((t) => t.id), ['main'],
          reason: 'una subtarea sin horario no infla la sección ni su count');
    });
  });

  group('H3 - invariante de fecha subtarea ↔ principal (edición)', () {
    final seedDay = DateTime(2026, 8, 10);

    test('cambiar la fecha de la principal PROPAGA el cambio a sus subtareas',
        () async {
      await seed(subtaskIds: ['s1', 's2']);
      final container = createContainer();
      addTearDown(container.dispose);
      final notifier = container.read(tasksProvider.notifier);

      final main = byId(container, 'main')!;
      final newDate = DateTime(2026, 8, 11);
      await notifier.updateTask(main.copyWith(
        title: 'Principal movida',
        scheduledDate: newDate,
      ));

      expect(byId(container, 'main')!.scheduledDate, newDate);
      expect(byId(container, 's1')!.scheduledDate, newDate,
          reason: 'la subtarea sigue SIEMPRE a la principal');
      expect(byId(container, 's2')!.scheduledDate, newDate);
      expect(tasksBox.get('s1')!.scheduledDate, newDate,
          reason: 'la propagación persiste en Hive');
      expect(tasksBox.get('s2')!.scheduledDate, newDate);
    });

    test('editar una subtarea NO rompe su vínculo de fecha (se reasigna a la '
        'de la principal)', () async {
      await seed(subtaskIds: ['s1']);
      final container = createContainer();
      addTearDown(container.dispose);
      final notifier = container.read(tasksProvider.notifier);

      final sub = byId(container, 's1')!;
      // Intento de guardarla con OTRA fecha: la invariante la reasigna.
      await notifier.updateTask(sub.copyWith(
        title: 'Subtarea editada',
        scheduledDate: DateTime(2026, 8, 15),
      ));

      expect(byId(container, 's1')!.title, 'Subtarea editada',
          reason: 'el resto de la edición SÍ se aplica');
      expect(byId(container, 's1')!.scheduledDate, seedDay,
          reason: 'la fecha vuelve a la de la principal');
      expect(byId(container, 'main')!.scheduledDate, seedDay);
      expect(tasksBox.get('s1')!.scheduledDate, seedDay,
          reason: 'la reasignación persiste en Hive');
    });

    test('persistencia: la fecha propagada sobrevive a un reinicio', () async {
      await seed(subtaskIds: ['s1', 's2']);
      final first = createContainer();
      final notifier = first.read(tasksProvider.notifier);
      final main = byId(first, 'main')!;
      await notifier.updateTask(main.copyWith(scheduledDate: DateTime(2026, 8, 12)));
      first.dispose();

      // "Reinicio": un contenedor nuevo lee las mismas cajas.
      final second = createContainer();
      addTearDown(second.dispose);

      expect(byId(second, 'main')!.scheduledDate, DateTime(2026, 8, 12));
      expect(byId(second, 's1')!.scheduledDate, DateTime(2026, 8, 12));
      expect(byId(second, 's2')!.scheduledDate, DateTime(2026, 8, 12));
    });
  });
}