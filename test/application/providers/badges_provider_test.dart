import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:slate_app/application/providers/streak_provider.dart';
import 'package:slate_app/data/hive/adapters/streak_adapter.dart';
import 'package:slate_app/data/hive/adapters/badge_adapter.dart';
import 'package:slate_app/data/hive/boxes/streaks_box.dart';
import 'package:slate_app/data/hive/boxes/badges_box.dart';
import 'package:slate_app/data/repositories/badge_repository_impl.dart';
import 'package:slate_app/domain/entities/badge.dart';
import 'package:slate_app/domain/entities/task.dart';
import 'package:slate_app/domain/enums/badge_type.dart';

/// Crea una tarea completada (o pendiente) programada en [scheduledDate].
Task _task(String id, DateTime scheduledDate, {bool isCompleted = true}) {
  return Task(
    id: id,
    title: 'Tarea $id',
    scheduledDate: scheduledDate,
    isCompleted: isCompleted,
    createdAt: scheduledDate,
    completedAt: isCompleted ? scheduledDate : null,
  );
}

DateTime _d(int y, int m, int d) => DateTime(y, m, d);
DateTime _now(int y, int m, int d) => DateTime(y, m, d, 12);

void main() {
  late Directory tempDir;
  late StreaksBox streaksBox;
  late BadgesBox badgesBox;
  late BadgeRepositoryImpl badgeRepository;
  late ProviderContainer container;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('slate_badges_test');
    Hive.init(tempDir.path);
    Hive.registerAdapter(StreakAdapter());
    Hive.registerAdapter(BadgeAdapter());
  });

  setUp(() async {
    streaksBox = StreaksBox();
    await streaksBox.init();
    badgesBox = BadgesBox();
    await badgesBox.init();

    badgeRepository = BadgeRepositoryImpl(badgesBox);

    container = ProviderContainer(
      overrides: [
        streaksBoxProvider.overrideWithValue(streaksBox),
        badgesBoxProvider.overrideWithValue(badgesBox),
      ],
    );
    addTearDown(container.dispose);
  });

  tearDown(() async {
    await Hive.close();
    await Hive.deleteBoxFromDisk('streaks');
    await Hive.deleteBoxFromDisk('badges');
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  group('badgesProvider - reflejo al instante del desbloqueo', () {
    test('se inicializa con las insignias ya persistidas en Hive', () async {
      final existing = Badge(
        id: 'b-existing',
        type: BadgeType.streak3,
        name: BadgeType.streak3.name,
        iconName: BadgeType.streak3.iconName,
        unlockedAt: DateTime(2026, 1, 10),
        isDisplayed: true,
      );
      await badgeRepository.add(existing);

      // Al leer el provider por primera vez toma el estado persistido.
      final badges = container.read(badgesProvider);
      expect(badges, hasLength(1));
      expect(badges.single.type, BadgeType.streak3);
    });

    test('tras recalculate que cruza un umbral, badgesProvider refleja la nueva insignia', () async {
      expect(container.read(badgesProvider), isEmpty);

      // Flujo real: completar tareas → recalculate con racha 3 (umbral streak3).
      await container.read(streakProvider.notifier).recalculate(
            tasks: [
              _task('a', _d(2026, 1, 12)),
              _task('b', _d(2026, 1, 13)),
              _task('c', _d(2026, 1, 14)),
            ],
            now: _now(2026, 1, 14),
          );

      // El estado del provider YA contiene la insignia (sin reiniciar la app).
      final badges = container.read(badgesProvider);
      expect(badges.map((b) => b.type), contains(BadgeType.streak3));
      expect(container.read(streakProvider).currentStreak, 3);

      // Y quedó persistida en Hive de forma consistente.
      expect(badgeRepository.getAll(), hasLength(1));
      expect(badgeRepository.getAll().single.type, BadgeType.streak3);
    });

    test('salto de varios días refleja TODOS los umbrales alcanzados', () async {
      final tasks = [
        for (var day = 1; day <= 14; day++) _task('t$day', _d(2026, 1, day)),
      ];
      await container.read(streakProvider.notifier).recalculate(
            tasks: tasks,
            now: _now(2026, 1, 14),
          );

      final types = container.read(badgesProvider).map((b) => b.type).toSet();
      expect(types, {
        BadgeType.streak3,
        BadgeType.streak7,
        BadgeType.streak14,
      });
      expect(container.read(badgesProvider), hasLength(3));
    });

    test('recálculo repetido es idempotente: no duplica insignias en el estado', () async {
      final threeDayTasks = [
        _task('a', _d(2026, 1, 12)),
        _task('b', _d(2026, 1, 13)),
        _task('c', _d(2026, 1, 14)),
      ];
      await container.read(streakProvider.notifier).recalculate(
            tasks: threeDayTasks,
            now: _now(2026, 1, 14),
          );
      await container.read(streakProvider.notifier).recalculate(
            tasks: threeDayTasks,
            now: _now(2026, 1, 14),
          );

      expect(container.read(badgesProvider), hasLength(1));
      expect(container.read(badgesProvider).single.type, BadgeType.streak3);
    });
  });

  group('badgesProvider - regresión R3b (desmarcar NO retira insignias)', () {
    test('desmarcar tareas baja la racha pero badgesProvider conserva las insignias', () async {
      await container.read(streakProvider.notifier).recalculate(
            tasks: [
              _task('a', _d(2026, 1, 12)),
              _task('b', _d(2026, 1, 13)),
              _task('c', _d(2026, 1, 14)),
            ],
            now: _now(2026, 1, 14),
          );
      expect(container.read(badgesProvider), hasLength(1));

      // Desmarcar la tarea ancla: racha baja a 2, la insignia permanece.
      await container.read(streakProvider.notifier).recalculate(
            tasks: [
              _task('a', _d(2026, 1, 12)),
              _task('b', _d(2026, 1, 13)),
              _task('c', _d(2026, 1, 14), isCompleted: false),
            ],
            now: _now(2026, 1, 14),
          );
      expect(container.read(streakProvider).currentStreak, 2);
      expect(container.read(badgesProvider), hasLength(1));

      // Desmarcar todo: racha 0, insignia intacta.
      await container.read(streakProvider.notifier).recalculate(
            tasks: [
              _task('a', _d(2026, 1, 12), isCompleted: false),
              _task('b', _d(2026, 1, 13), isCompleted: false),
              _task('c', _d(2026, 1, 14), isCompleted: false),
            ],
            now: _now(2026, 1, 14),
          );
      expect(container.read(streakProvider).currentStreak, 0);
      expect(container.read(badgesProvider), hasLength(1));
      expect(container.read(badgesProvider).single.type, BadgeType.streak3);
    });
  });
}
