import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:slate_app/application/providers/streak_provider.dart';
import 'package:slate_app/data/hive/adapters/streak_adapter.dart';
import 'package:slate_app/data/hive/adapters/badge_adapter.dart';
import 'package:slate_app/data/hive/boxes/streaks_box.dart';
import 'package:slate_app/data/hive/boxes/badges_box.dart';
import 'package:slate_app/data/repositories/streak_repository_impl.dart';
import 'package:slate_app/data/repositories/badge_repository_impl.dart';
import 'package:slate_app/domain/entities/task.dart';
import 'package:slate_app/domain/enums/badge_type.dart';

/// Crea una tarea completada (o pendiente) programada en [scheduledDate].
Task _task(String id, DateTime scheduledDate,
    {bool isCompleted = true, bool isSubtask = false, String? parentTaskId}) {
  return Task(
    id: id,
    title: 'Tarea $id',
    scheduledDate: scheduledDate,
    isCompleted: isCompleted,
    createdAt: scheduledDate,
    completedAt: isCompleted ? scheduledDate : null,
    parentTaskId: parentTaskId,
    isSubtask: isSubtask,
  );
}

DateTime _d(int y, int m, int d) => DateTime(y, m, d);
DateTime _day(int y, int m, int d) => DateTime.utc(y, m, d);
DateTime _now(int y, int m, int d) => DateTime(y, m, d, 12);

void main() {
  late Directory tempDir;
  late StreaksBox streaksBox;
  late BadgesBox badgesBox;
  late StreakRepositoryImpl streakRepository;
  late BadgeRepositoryImpl badgeRepository;
  late StreakNotifier notifier;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('slate_streak_test');
    Hive.init(tempDir.path);
    Hive.registerAdapter(StreakAdapter());
    Hive.registerAdapter(BadgeAdapter());
  });

  setUp(() async {
    streaksBox = StreaksBox();
    await streaksBox.init();
    badgesBox = BadgesBox();
    await badgesBox.init();

    streakRepository = StreakRepositoryImpl(streaksBox);
    badgeRepository = BadgeRepositoryImpl(badgesBox);
    notifier = StreakNotifier(streakRepository, BadgesNotifier(badgeRepository));
  });

  tearDown(() async {
    await Hive.close();
    await Hive.deleteBoxFromDisk('streaks');
    await Hive.deleteBoxFromDisk('badges');
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  group('StreakNotifier.recalculate (integración con Hive)', () {
    test('R1a: completar una tarea con fecha pasada acredita scheduledDate', () async {
      // Ayer completado, "hoy" es miércoles 14.
      await notifier.recalculate(
        tasks: [_task('a', _d(2026, 1, 13))],
        now: _now(2026, 1, 14),
      );

      expect(notifier.state.currentStreak, 1);
      expect(notifier.state.lastCompletedDate, _day(2026, 1, 13)); // ayer, no hoy
      expect(notifier.state.longestStreak, 1);

      // Se completa además la tarea de hoy → racha 2.
      await notifier.recalculate(
        tasks: [
          _task('a', _d(2026, 1, 13)),
          _task('b', _d(2026, 1, 14)),
        ],
        now: _now(2026, 1, 14),
      );

      expect(notifier.state.currentStreak, 2);
      expect(notifier.state.longestStreak, 2);
      expect(notifier.state.lastCompletedDate, _day(2026, 1, 14));
    });

    test('R2a: completar ayer DESPUÉS de hoy cuenta ambos días', () async {
      // Paso 1: ya marqué hoy.
      await notifier.recalculate(
        tasks: [_task('wed', _d(2026, 1, 14))],
        now: _now(2026, 1, 14),
      );
      expect(notifier.state.currentStreak, 1);

      // Paso 2: luego completo una tarea de ayer → debe sumar ayer también.
      await notifier.recalculate(
        tasks: [
          _task('wed', _d(2026, 1, 14)),
          _task('tue', _d(2026, 1, 13)),
        ],
        now: _now(2026, 1, 14),
      );
      expect(notifier.state.currentStreak, 2);
      expect(notifier.state.longestStreak, 2);

      // Persistido en Hive de forma consistente.
      final persisted = streaksBox.getStreak();
      expect(persisted.currentStreak, 2);
      expect(persisted.longestStreak, 2);
      expect(persisted.lastCompletedDate, _day(2026, 1, 14));
    });

    test('R3b: desmarcar baja la racha y las insignias NO se retiran', () async {
      // Racha de 3 días → se desbloquea la insignia streak3.
      await notifier.recalculate(
        tasks: [
          _task('a', _d(2026, 1, 12)),
          _task('b', _d(2026, 1, 13)),
          _task('c', _d(2026, 1, 14)),
        ],
        now: _now(2026, 1, 14),
      );
      expect(notifier.state.currentStreak, 3);
      expect(badgeRepository.getAll(), hasLength(1));
      expect(badgeRepository.getAll().single.type, BadgeType.streak3);

      // Desmarcar la tarea del ancla (miércoles): la racha BAJA a 2.
      await notifier.recalculate(
        tasks: [
          _task('a', _d(2026, 1, 12)),
          _task('b', _d(2026, 1, 13)),
          _task('c', _d(2026, 1, 14), isCompleted: false),
        ],
        now: _now(2026, 1, 14),
      );
      expect(notifier.state.currentStreak, 2);
      expect(notifier.state.longestStreak, 3); // el máximo no baja
      expect(badgeRepository.getAll(), hasLength(1)); // la insignia NO se retira

      // Desmarcar todo: racha 0 y lastCompletedDate limpio; insignia intacta.
      await notifier.recalculate(
        tasks: [
          _task('a', _d(2026, 1, 12), isCompleted: false),
          _task('b', _d(2026, 1, 13), isCompleted: false),
          _task('c', _d(2026, 1, 14), isCompleted: false),
        ],
        now: _now(2026, 1, 14),
      );
      expect(notifier.state.currentStreak, 0);
      expect(notifier.state.longestStreak, 3);
      expect(notifier.state.lastCompletedDate, isNull);
      expect(badgeRepository.getAll(), hasLength(1));
    });

    test('salto de varios días desbloquea todos los umbrales intermedios', () async {
      // Backfill: 14 días consecutivos completados de una sola vez.
      final tasks = [
        for (var day = 1; day <= 14; day++) _task('t$day', _d(2026, 1, day)),
      ];
      await notifier.recalculate(
        tasks: tasks,
        now: _now(2026, 1, 14),
      );

      expect(notifier.state.currentStreak, 14);
      expect(notifier.state.longestStreak, 14);

      final badges = badgeRepository.getAll();
      expect(badges, hasLength(3));
      expect(badges.map((b) => b.type).toSet(), {
        BadgeType.streak3,
        BadgeType.streak7,
        BadgeType.streak14,
      });

      // Bajar hasta 0 NO retira ninguna insignia.
      await notifier.recalculate(
        tasks: [for (final t in tasks) t.copyWith(isCompleted: false)],
        now: _now(2026, 1, 14),
      );
      expect(notifier.state.currentStreak, 0);
      expect(badgeRepository.getAll(), hasLength(3));
    });

    test('recálculo repetido es idempotente (no duplica insignias)', () async {
      await notifier.recalculate(
        tasks: [
          _task('a', _d(2026, 1, 12)),
          _task('b', _d(2026, 1, 13)),
          _task('c', _d(2026, 1, 14)),
        ],
        now: _now(2026, 1, 14),
      );
      await notifier.recalculate(
        tasks: [
          _task('a', _d(2026, 1, 12)),
          _task('b', _d(2026, 1, 13)),
          _task('c', _d(2026, 1, 14)),
        ],
        now: _now(2026, 1, 14),
      );

      expect(notifier.state.currentStreak, 3);
      expect(badgeRepository.getAll(), hasLength(1)); // streak3, sin duplicados
    });

    test('una subtarea completada NO activa la racha (H2 regla de producto)',
        () async {
      // Solo una subtarea completada HOY → la racha permanece en 0 (las
      // subtareas no son "misiones" del Slate System).
      await notifier.recalculate(
        tasks: [
          _task('s1', _d(2026, 1, 14),
              isSubtask: true, parentTaskId: 'main'),
        ],
        now: _now(2026, 1, 14),
      );

      expect(notifier.state.currentStreak, 0);
      expect(notifier.state.lastCompletedDate, isNull);
      expect(badgeRepository.getAll(), isEmpty);

      // La PRINCIPAL completada con su subtarea arrastrada SÍ activa el día.
      await notifier.recalculate(
        tasks: [
          _task('main', _d(2026, 1, 14)),
          _task('s1', _d(2026, 1, 14),
              isSubtask: true, parentTaskId: 'main'),
        ],
        now: _now(2026, 1, 14),
      );

      expect(notifier.state.currentStreak, 1);
      expect(notifier.state.lastCompletedDate, _day(2026, 1, 14));
      expect(badgeRepository.getAll(), isEmpty,
          reason: '1 día no alcanza el umbral streak3');
    });
  });
}
