import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:slate_app/application/providers/player_provider.dart';
import 'package:slate_app/application/services/player_xp_calculator.dart';
import 'package:slate_app/data/hive/adapters/player_profile_adapter.dart';
import 'package:slate_app/data/hive/boxes/player_progress_box.dart';
import 'package:slate_app/data/repositories/player_repository_impl.dart';
import 'package:slate_app/domain/enums/player_rank.dart';
import 'package:slate_app/domain/enums/task_priority.dart';

void main() {
  late Directory tempDir;
  late PlayerProgressBox playerBox;
  late PlayerRepositoryImpl repository;
  late PlayerNotifier notifier;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('slate_player_test');
    Hive.init(tempDir.path);
    Hive.registerAdapter(PlayerProfileAdapter());
  });

  setUp(() async {
    playerBox = PlayerProgressBox();
    await playerBox.init();
    repository = PlayerRepositoryImpl(playerBox);
    notifier = PlayerNotifier(repository);
  });

  tearDown(() async {
    await Hive.close();
    await Hive.deleteBoxFromDisk('player_progress');
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  group('PlayerXpCalculator - curva de niveles (decisión A)', () {
    test('xpRequiredForLevel sigue la fórmula 100·nivel²', () {
      expect(PlayerXpCalculator.xpRequiredForLevel(1), 0,
          reason: 'el nivel 1 es el nivel base de arranque');
      expect(PlayerXpCalculator.xpRequiredForLevel(2), 100);
      expect(PlayerXpCalculator.xpRequiredForLevel(3), 400);
      expect(PlayerXpCalculator.xpRequiredForLevel(4), 900);
      expect(PlayerXpCalculator.xpRequiredForLevel(5), 1600);
    });

    test('levelForXp respeta los umbrales exactos', () {
      expect(PlayerXpCalculator.levelForXp(0), 1);
      expect(PlayerXpCalculator.levelForXp(99), 1);
      expect(PlayerXpCalculator.levelForXp(100), 2);
      expect(PlayerXpCalculator.levelForXp(399), 2);
      expect(PlayerXpCalculator.levelForXp(400), 3);
      expect(PlayerXpCalculator.levelForXp(900), 4);
      expect(PlayerXpCalculator.levelForXp(1600), 5);
    });

    test('rango E→S por tramos de nivel', () {
      expect(PlayerXpCalculator.rankForLevel(1), PlayerRank.e);
      expect(PlayerXpCalculator.rankForLevel(9), PlayerRank.e);
      expect(PlayerXpCalculator.rankForLevel(10), PlayerRank.d);
      expect(PlayerXpCalculator.rankForLevel(19), PlayerRank.d);
      expect(PlayerXpCalculator.rankForLevel(20), PlayerRank.c);
      expect(PlayerXpCalculator.rankForLevel(29), PlayerRank.c);
      expect(PlayerXpCalculator.rankForLevel(30), PlayerRank.b);
      expect(PlayerXpCalculator.rankForLevel(49), PlayerRank.b);
      expect(PlayerXpCalculator.rankForLevel(50), PlayerRank.a);
      expect(PlayerXpCalculator.rankForLevel(69), PlayerRank.a);
      expect(PlayerXpCalculator.rankForLevel(70), PlayerRank.s);
      expect(PlayerXpCalculator.rankForLevel(120), PlayerRank.s);
    });

    test('progreso a siguiente nivel: 0 en nivel base, 1 en el umbral', () {
      expect(PlayerXpCalculator.progressToNextLevel(0, 1), 0.0);
      expect(PlayerXpCalculator.progressToNextLevel(50, 1), 0.5);
      expect(PlayerXpCalculator.progressToNextLevel(99, 1), closeTo(0.99, 0.001));
      expect(PlayerXpCalculator.progressToNextLevel(100, 2), 0.0);
      expect(PlayerXpCalculator.progressToNextLevel(150, 2), closeTo(50 / 300, 0.001));
      expect(PlayerXpCalculator.xpSpanForLevel(1), 100);
      expect(PlayerXpCalculator.xpSpanForLevel(2), 300);
      expect(PlayerXpCalculator.xpSpanForLevel(3), 500);
    });
  });

  group('PlayerNotifier - XP por prioridad y backfill', () {
    test('backfill: perfil inicial nivel 1 con 0 XP (no recrear histórico)',
        () async {
      expect(notifier.state.totalXp, 0);
      expect(notifier.state.level, 1);
      expect(notifier.state.shownLevelUps, isEmpty);

      // Persistido en Hive de forma consistente.
      final persisted = playerBox.getProfile();
      expect(persisted.totalXp, 0);
      expect(persisted.level, 1);
    });

    test('addTaskXp suma +10 / +15 / +20 según prioridad', () async {
      await notifier.addTaskXp(TaskPriority.normal);
      expect(notifier.state.totalXp, 10);
      await notifier.addTaskXp(TaskPriority.medium);
      expect(notifier.state.totalXp, 25);
      await notifier.addTaskXp(TaskPriority.high);
      expect(notifier.state.totalXp, 45);

      // El nivel sigue siendo 1 (aún no llega a 100 XP).
      expect(notifier.state.level, 1);
    });

    test('removeTaskXp RESTA el XP ganado (simetría anti-exploit)', () async {
      await notifier.addTaskXp(TaskPriority.high); // +20
      await notifier.addTaskXp(TaskPriority.high); // +40
      expect(notifier.state.totalXp, 40);

      await notifier.removeTaskXp(TaskPriority.high);
      expect(notifier.state.totalXp, 20);
      await notifier.removeTaskXp(TaskPriority.high);
      expect(notifier.state.totalXp, 0);
    });

    test('el XP total nunca baja de 0 al desmarcar', () async {
      await notifier.removeTaskXp(TaskPriority.high);
      expect(notifier.state.totalXp, 0);
    });
  });

  group('PlayerNotifier - nivel irreversible y level-up único', () {
    Future<void> reachLevel3() async {
      // 400 XP totales: 20 tareas altas (20×20).
      for (var i = 0; i < 20; i++) {
        await notifier.addTaskXp(TaskPriority.high);
      }
      expect(notifier.state.totalXp, 400);
    }

    test('al alcanzar un umbral devuelve el nivel y lo registra UNA vez',
        () async {
      // 4 tareas altas = 80 → nivel 1; 5ª = 100 → nivel 2 (devuelve 2).
      for (var i = 0; i < 4; i++) {
        expect(await notifier.addTaskXp(TaskPriority.high), isNull);
      }
      final reached = await notifier.addTaskXp(TaskPriority.high);
      expect(reached, 2);
      expect(notifier.state.level, 2);
      expect(notifier.state.shownLevelUps, {2});

      // Desmarcar NO baja el nivel; volver a marcar NO notifica otra vez.
      await notifier.removeTaskXp(TaskPriority.high);
      expect(notifier.state.totalXp, 80);
      expect(notifier.state.level, 2);
      expect(await notifier.addTaskXp(TaskPriority.high), isNull,
          reason: 'la transición al nivel 2 ya fue consumida');
      expect(notifier.state.shownLevelUps, {2},
          reason: 'el set de level-ups mostrados queda único');
    });

    test('irreversibilidad: desmarcar TODO no baja el nivel alcanzado',
        () async {
      await reachLevel3();
      expect(notifier.state.level, 3);

      // Desmarcar todas las tareas: XP vuelve a 0, el nivel se mantiene en 3.
      for (var i = 0; i < 20; i++) {
        await notifier.removeTaskXp(TaskPriority.high);
      }
      expect(notifier.state.totalXp, 0);
      expect(notifier.state.level, 3,
          reason: 'el tope del nivel alcanzado NUNCA baja');

      // Persistido: el nivel cacheado también queda en 3.
      expect(playerBox.getProfile().level, 3);
    });

    test('persistencia: el provider actualiza Hive y refleja al instante',
        () async {
      await notifier.addTaskXp(TaskPriority.high);
      await notifier.addTaskXp(TaskPriority.high);

      // Reflejo al instante en el estado del notifier.
      expect(notifier.state.totalXp, 40);

      // Y persistido en Hive (fuente de verdad relativa).
      final persisted = playerBox.getProfile();
      expect(persisted.totalXp, 40);

      // Un notifier nuevo (p. ej. tras reiniciar) lee el estado persistido.
      final restarted = PlayerNotifier(repository);
      expect(restarted.state.totalXp, 40);
    });

    test('cada nivel se notifica una sola vez al subir varios niveles',
        () async {
      // Salto directo de nivel 1 a nivel 3 (400 XP en 20 tareas altas).
      final levelUps = <int?>[];
      for (var i = 0; i < 20; i++) {
        levelUps.add(await notifier.addTaskXp(TaskPriority.high));
      }
      expect(levelUps.whereType<int>().toList(), [2, 3],
          reason: 'solo se notifican los niveles NUEVOS alcanzados');
      expect(notifier.state.shownLevelUps, {2, 3});
      expect(notifier.state.level, 3);
    });
  });

  group('PlayerNotifier - eventos de subtarea preparados (F4)', () {
    test('addSubtaskXp suma +2 y removeSubtaskXp resta (sin UI todavía)',
        () async {
      await notifier.addSubtaskXp();
      expect(notifier.state.totalXp, 2);
      await notifier.addSubtaskXp();
      expect(notifier.state.totalXp, 4);

      await notifier.removeSubtaskXp();
      expect(notifier.state.totalXp, 2);
    });

    test('los eventos de subtarea cooperan con la curva de niveles', () async {
      // 50 subtareas = 100 XP → cruza al nivel 2.
      for (var i = 0; i < 50; i++) {
        await notifier.addSubtaskXp();
      }
      expect(notifier.state.totalXp, 100);
      expect(notifier.state.level, 2);
      expect(notifier.state.shownLevelUps, {2});
    });
  });
}