import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:slate_app/application/providers/player_provider.dart';
import 'package:slate_app/application/providers/quest_provider.dart';
import 'package:slate_app/data/hive/adapters/companion_state_adapter.dart';
import 'package:slate_app/data/hive/adapters/player_profile_adapter.dart';
import 'package:slate_app/data/hive/adapters/task_adapter.dart';
import 'package:slate_app/data/hive/boxes/companion_state_box.dart';
import 'package:slate_app/data/hive/boxes/player_progress_box.dart';
import 'package:slate_app/data/hive/boxes/tasks_box.dart';
import 'package:slate_app/data/repositories/companion_state_repository_impl.dart';
import 'package:slate_app/data/repositories/player_repository_impl.dart';
import 'package:slate_app/domain/entities/task.dart';
import 'package:slate_app/domain/enums/task_priority.dart';

Task _task(
  String id,
  DateTime day, {
  bool isCompleted = false,
  DateTime? completedAt,
  bool isSubtask = false,
  String? parentTaskId,
}) {
  return Task(
    id: id,
    title: 'Tarea $id',
    scheduledDate: day,
    isCompleted: isCompleted,
    completedAt: completedAt,
    createdAt: day,
    parentTaskId: parentTaskId,
    isSubtask: isSubtask,
  );
}

void main() {
  late Directory tempDir;
  late CompanionStateBox companionBox;
  late PlayerProgressBox playerBox;
  late TasksBox tasksBox;
  late PlayerNotifier playerNotifier;
  late QuestNotifier notifier;
  late DateTime now;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('slate_quest_test');
    Hive.init(tempDir.path);
    Hive.registerAdapter(CompanionStateAdapter());
    Hive.registerAdapter(PlayerProfileAdapter());
    Hive.registerAdapter(TaskAdapter());
  });

  setUp(() async {
    companionBox = CompanionStateBox();
    await companionBox.init();
    playerBox = PlayerProgressBox();
    await playerBox.init();
    tasksBox = TasksBox();
    await tasksBox.init();
    now = DateTime(2026, 8, 10, 9, 0);
    playerNotifier = PlayerNotifier(PlayerRepositoryImpl(playerBox));
    // `notifier` se construye en cada test DESPUÉS de poblar las tareas del día
    // (ver [createNotifier]). En producción las cajas se abren antes de
    // runApp y `questProvider` se construye cuando Home ya tiene las tareas
    // cargadas, así que la "primera decisión" del día siempre ve el calendario
    // real. Construirlo aquí con 0 tareas decidiría (y persistiría) la
    // visibilidad del día como falsa antes de tiempo.
  });

  /// Construye el notifier con las tareas y la hora YA establecidas, igual que
  /// hace `questProvider` en la app real (tareas presentes al primer sync).
  QuestNotifier createNotifier() => QuestNotifier(
        repository: CompanionStateRepositoryImpl(companionBox),
        playerNotifier: playerNotifier,
        readTasks: () => tasksBox.getAll(),
        readNow: () => now,
      );

  tearDown(() async {
    await Hive.close();
    await Hive.deleteBoxFromDisk('companion_state');
    await Hive.deleteBoxFromDisk('player_progress');
    await Hive.deleteBoxFromDisk('tasks');
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  group('Visibilidad (decisión C: ≥3 tareas hoy)', () {
    test('oculta la quest con <3 tareas programadas', () async {
      await tasksBox.add(_task('a', now));
      await tasksBox.add(_task('b', now));
      notifier = createNotifier();

      expect(notifier.state.isVisible, isFalse);
      expect(notifier.state.canClaim, isFalse);
    });

    test('muestra la quest con ≥3 tareas programadas', () async {
      await tasksBox.add(_task('a', now));
      await tasksBox.add(_task('b', now));
      await tasksBox.add(_task('c', now));
      notifier = createNotifier();

      expect(notifier.state.isVisible, isTrue);
      expect(notifier.state.completedToday, 0);
    });

    test('la visibilidad se recalcula dinámicamente al cambiar tareas', () async {
      // Inicio con 3 tareas → visible.
      await tasksBox.add(_task('a', now));
      await tasksBox.add(_task('b', now));
      await tasksBox.add(_task('c', now));
      notifier = createNotifier();
      expect(notifier.state.isVisible, isTrue);

      // Borrar tareas recalcula la visibilidad: con 1 tarea ya no es visible.
      await tasksBox.delete('a');
      await tasksBox.delete('b');
      notifier.refresh();
      expect(notifier.state.isVisible, isFalse,
          reason: 'la visibilidad se recalcula dinámicamente');
    });

    test('la visibilidad sobrevive a un reinicio si las tareas persisten', () async {
      await tasksBox.add(_task('a', now));
      await tasksBox.add(_task('b', now));
      await tasksBox.add(_task('c', now));
      notifier = createNotifier();
      expect(notifier.state.isVisible, isTrue);

      // Reiniciar el notifier con las tareas aún en la caja.
      final restarted = QuestNotifier(
        repository: CompanionStateRepositoryImpl(companionBox),
        playerNotifier: PlayerNotifier(PlayerRepositoryImpl(playerBox)),
        readTasks: () => tasksBox.getAll(),
        readNow: () => now,
      );
      expect(restarted.state.isVisible, isTrue);
    });

    test('si no había suficientes tareas, añadir más hace visible la quest',
        () async {
      // Solo 2 tareas al inicio → no visible.
      await tasksBox.add(_task('a', now));
      await tasksBox.add(_task('b', now));
      notifier = createNotifier();
      expect(notifier.state.isVisible, isFalse);

      // Se añaden más tareas HOY: la quest se vuelve visible.
      await tasksBox.add(_task('c', now));
      notifier.refresh();
      expect(notifier.state.isVisible, isTrue,
          reason: 'añadir tareas activa dinámicamente la visibilidad');
    });
  });

  group('Progreso y reclamación (F3, decisión C)', () {
    test('al completar 3 tareas la quest pasa a canClaim', () async {
      await tasksBox.add(_task('a', now));
      await tasksBox.add(_task('b', now));
      await tasksBox.add(_task('c', now));
      notifier = createNotifier();

      await tasksBox.update(_task('a', now,
          isCompleted: true, completedAt: DateTime(2026, 8, 10, 10)));
      await tasksBox.update(_task('b', now,
          isCompleted: true, completedAt: DateTime(2026, 8, 10, 11)));
      notifier.refresh();
      expect(notifier.state.completedToday, 2);
      expect(notifier.state.canClaim, isFalse);

      await tasksBox.update(_task('c', now,
          isCompleted: true, completedAt: DateTime(2026, 8, 10, 12)));
      notifier.refresh();
      expect(notifier.state.completedToday, 3);
      expect(notifier.state.canClaim, isTrue);
    });

    test('reclamar da +25 XP UNA sola vez (2º intento sin premio)', () async {
      await tasksBox.add(_task('a', now));
      await tasksBox.add(_task('b', now));
      await tasksBox.add(_task('c', now));
      await tasksBox.update(_task('a', now,
          isCompleted: true, completedAt: DateTime(2026, 8, 10, 10)));
      await tasksBox.update(_task('b', now,
          isCompleted: true, completedAt: DateTime(2026, 8, 10, 11)));
      await tasksBox.update(_task('c', now,
          isCompleted: true, completedAt: DateTime(2026, 8, 10, 12)));
      notifier = createNotifier();

      final xpBefore = playerNotifier.state.totalXp;
      final levelUp = await notifier.claim();
      expect(levelUp, isNull, reason: '25 XP no cruza el umbral del nivel 2');
      expect(notifier.state.isClaimed, isTrue);
      expect(playerNotifier.state.totalXp, xpBefore + 25);
      expect(notifier.state.canClaim, isFalse);

      // Segundo intento: NO se otorga el premio de nuevo.
      final xpAfter = playerNotifier.state.totalXp;
      final secondLevelUp = await notifier.claim();
      expect(secondLevelUp, isNull);
      expect(playerNotifier.state.totalXp, xpAfter,
          reason: 'reclamable 1 vez por día');
    });

    test('reclamar exige acción explícita: sin claim no hay XP', () async {
      await tasksBox.add(_task('a', now));
      await tasksBox.add(_task('b', now));
      await tasksBox.add(_task('c', now));
      await tasksBox.update(_task('a', now,
          isCompleted: true, completedAt: DateTime(2026, 8, 10, 10)));
      await tasksBox.update(_task('b', now,
          isCompleted: true, completedAt: DateTime(2026, 8, 10, 11)));
      await tasksBox.update(_task('c', now,
          isCompleted: true, completedAt: DateTime(2026, 8, 10, 12)));
      notifier = createNotifier();

      expect(notifier.state.canClaim, isTrue);
      expect(playerNotifier.state.totalXp, 0,
          reason: 'completar 3 tareas aún no ha otorgado el premio de la quest');
    });

    test('el estado reclamado PERSISTE en Hive (sobrevive al reinicio)', () async {
      await tasksBox.add(_task('a', now));
      await tasksBox.add(_task('b', now));
      await tasksBox.add(_task('c', now));
      await tasksBox.update(_task('a', now,
          isCompleted: true, completedAt: DateTime(2026, 8, 10, 10)));
      await tasksBox.update(_task('b', now,
          isCompleted: true, completedAt: DateTime(2026, 8, 10, 11)));
      await tasksBox.update(_task('c', now,
          isCompleted: true, completedAt: DateTime(2026, 8, 10, 12)));
      notifier = createNotifier();
      await notifier.claim();

      final restarted = QuestNotifier(
        repository: CompanionStateRepositoryImpl(companionBox),
        playerNotifier: PlayerNotifier(PlayerRepositoryImpl(playerBox)),
        readTasks: () => tasksBox.getAll(),
        readNow: () => now,
      );
      expect(restarted.state.isClaimed, isTrue);
      expect(restarted.state.canClaim, isFalse);
    });

    test('reutiliza shownLevelUps: si el +25 cruza un nivel ya consumido, '
        'claim NO devuelve level-up ni duplica SnackBar', () async {
      // 400 XP = nivel 3 con transiciones 2 y 3 ya consumidas.
      for (var i = 0; i < 20; i++) {
        await playerNotifier.addTaskXp(TaskPriority.high);
      }
      expect(playerNotifier.state.level, 3);

      await tasksBox.add(_task('a', now));
      await tasksBox.add(_task('b', now));
      await tasksBox.add(_task('c', now));
      await tasksBox.update(_task('a', now,
          isCompleted: true, completedAt: DateTime(2026, 8, 10, 10)));
      await tasksBox.update(_task('b', now,
          isCompleted: true, completedAt: DateTime(2026, 8, 10, 11)));
      await tasksBox.update(_task('c', now,
          isCompleted: true, completedAt: DateTime(2026, 8, 10, 12)));
      notifier = createNotifier();

      final levelUp = await notifier.claim();
      expect(levelUp, isNull,
          reason: 'el nivel derivado (3) ya fue mostrado; no hay SnackBar');
      expect(notifier.state.isClaimed, isTrue);
    });

    test('si el +25 SÍ cruza un nivel nuevo, claim devuelve el nivel una vez',
        () async {
      // 90 XP (nivel 1) → claim +25 = 115 → nivel 2 NUEVO.
      await playerNotifier.addSubtaskXp(); // +2 (45 veces = 90)
      for (var i = 0; i < 44; i++) {
        await playerNotifier.addSubtaskXp();
      }
      expect(playerNotifier.state.totalXp, 90);
      expect(playerNotifier.state.level, 1);

      await tasksBox.add(_task('a', now));
      await tasksBox.add(_task('b', now));
      await tasksBox.add(_task('c', now));
      await tasksBox.update(_task('a', now,
          isCompleted: true, completedAt: DateTime(2026, 8, 10, 10)));
      await tasksBox.update(_task('b', now,
          isCompleted: true, completedAt: DateTime(2026, 8, 10, 11)));
      await tasksBox.update(_task('c', now,
          isCompleted: true, completedAt: DateTime(2026, 8, 10, 12)));
      notifier = createNotifier();

      final levelUp = await notifier.claim();
      expect(levelUp, 2);
      expect(playerNotifier.state.level, 2);

      // Segundo claim (hipotético fallo de guard): no devuelve 2 otra vez.
      final second = await notifier.claim();
      expect(second, isNull);
      expect(notifier.state.isClaimed, isTrue);
    });
  });

  group('H2 — subtareas NO cuentan (regla de producto)', () {
    test('una subtarea completada NO sube completedToday', () async {
      await tasksBox.add(_task('a', now));
      await tasksBox.add(_task('b', now));
      await tasksBox.add(_task('c', now));
      await tasksBox.add(_task('a1', now,
          isSubtask: true, parentTaskId: 'a'));
      notifier = createNotifier();

      await tasksBox.update(_task('a', now,
          isCompleted: true, completedAt: DateTime(2026, 8, 10, 10)));
      await tasksBox.update(_task('b', now,
          isCompleted: true, completedAt: DateTime(2026, 8, 10, 11)));
      await tasksBox.update(_task('a1', now,
          isCompleted: true,
          completedAt: DateTime(2026, 8, 10, 12),
          isSubtask: true,
          parentTaskId: 'a'));
      notifier.refresh();

      expect(notifier.state.completedToday, 2,
          reason: 'la subtarea a1 no es una misión (solo +2 XP si se marca)');
      expect(notifier.state.canClaim, isFalse);
    });

    test('3 subtareas NO hacen visible la quest', () async {
      await tasksBox.add(_task('a1', now,
          isSubtask: true, parentTaskId: 'a'));
      await tasksBox.add(_task('a2', now,
          isSubtask: true, parentTaskId: 'a'));
      await tasksBox.add(_task('a3', now,
          isSubtask: true, parentTaskId: 'a'));
      notifier = createNotifier();

      expect(notifier.state.isVisible, isFalse,
          reason: 'las subtareas son sub-bloques, no misiones');
    });

    test('el arrastre de la principal con subtareas NO satisface la quest',
        () async {
      // Una principal + 2 subtareas = 3 ítems marcables, pero solo la
      // principal cuenta como misión para la quest.
      await tasksBox.add(_task('a', now));
      await tasksBox.add(_task('a1', now,
          isSubtask: true, parentTaskId: 'a'));
      await tasksBox.add(_task('a2', now,
          isSubtask: true, parentTaskId: 'a'));
      notifier = createNotifier();

      // Completar la principal arrastra a1 y a2 (como hace toggleComplete).
      await tasksBox.update(_task('a', now,
          isCompleted: true, completedAt: DateTime(2026, 8, 10, 10)));
      await tasksBox.update(_task('a1', now,
          isCompleted: true,
          completedAt: DateTime(2026, 8, 10, 10),
          isSubtask: true,
          parentTaskId: 'a'));
      await tasksBox.update(_task('a2', now,
          isCompleted: true,
          completedAt: DateTime(2026, 8, 10, 10),
          isSubtask: true,
          parentTaskId: 'a'));
      notifier.refresh();

      expect(notifier.state.completedToday, 1);
      expect(notifier.state.canClaim, isFalse,
          reason: '3 marcas con subs no bastan: solo cuenta la principal');
    });
  });

  group('Reset diario', () {
    test('al día siguiente la quest queda sin reclamar y se re-decide', () async {
      await tasksBox.add(_task('a', now));
      await tasksBox.add(_task('b', now));
      await tasksBox.add(_task('c', now));
      await tasksBox.update(_task('a', now,
          isCompleted: true, completedAt: DateTime(2026, 8, 10, 10)));
      await tasksBox.update(_task('b', now,
          isCompleted: true, completedAt: DateTime(2026, 8, 10, 11)));
      await tasksBox.update(_task('c', now,
          isCompleted: true, completedAt: DateTime(2026, 8, 10, 12)));
      notifier = createNotifier();
      await notifier.claim();
      expect(notifier.state.isClaimed, isTrue);

      // Cambia el día: las tareas siguen existiendo (misma fecha programada
      // 10/ago), por lo que la visibilidad de HOY se re-decide y la quest
      // queda sin reclamar para el día nuevo.
      now = DateTime(2026, 8, 11, 7, 0);
      notifier.refresh();
      expect(notifier.state.isClaimed, isFalse,
          reason: 'la reclamación es por día (questClaimedOn)');
      expect(notifier.state.todayKey, isNot('2026-8-10'));
    });

    test('el reinicio usa la fecha de hoy (questClaimedOn)', () async {
      await tasksBox.add(_task('a', now));
      await tasksBox.add(_task('b', now));
      await tasksBox.add(_task('c', now));
      await tasksBox.update(_task('a', now,
          isCompleted: true, completedAt: DateTime(2026, 8, 10, 10)));
      await tasksBox.update(_task('b', now,
          isCompleted: true, completedAt: DateTime(2026, 8, 10, 11)));
      await tasksBox.update(_task('c', now,
          isCompleted: true, completedAt: DateTime(2026, 8, 10, 12)));
      notifier = createNotifier();
      await notifier.claim();

      final persisted = companionBox.getState();
      expect(persisted.questClaimedOn, '2026-8-10');
    });
  });
}