import 'package:flutter_test/flutter_test.dart';

import 'package:slate_app/application/services/fortnight_calculator.dart';
import 'package:slate_app/application/services/notification_ids.dart';
import 'package:slate_app/domain/entities/badge.dart';
import 'package:slate_app/domain/entities/task.dart';
import 'package:slate_app/domain/enums/badge_type.dart';

void main() {
  const hour = fortnightSummaryReminderHour;

  group('periodForDate — límites de las quincenas', () {
    test('día 15 → quincena-1 (1..15)', () {
      final p = FortnightCalculator.periodForDate(DateTime(2026, 8, 15));
      expect(p.start, DateTime(2026, 8, 1));
      expect(p.end, DateTime(2026, 8, 15));
    });

    test('día 16 → quincena-2 (16..31 en agosto)', () {
      final p = FortnightCalculator.periodForDate(DateTime(2026, 8, 16));
      expect(p.start, DateTime(2026, 8, 16));
      expect(p.end, DateTime(2026, 8, 31));
    });

    test('octubre (31 días): día 31 → quincena-2 termina el 31', () {
      final p = FortnightCalculator.periodForDate(DateTime(2026, 10, 31));
      expect(p.end, DateTime(2026, 10, 31));
    });

    test('febrero (28 días): día 28 → quincena-2 termina el 28', () {
      final p = FortnightCalculator.periodForDate(DateTime(2026, 2, 28));
      expect(p.start, DateTime(2026, 2, 16));
      expect(p.end, DateTime(2026, 2, 28));
    });

    test('febrero bisiesto (2028): día 29 → quincena-2 termina el 29', () {
      final p = FortnightCalculator.periodForDate(DateTime(2028, 2, 29));
      expect(p.end, DateTime(2028, 2, 29));
    });
  });

  group('periodForFireTime — periodo que reporta cada disparo', () {
    test('disparo del día 16 → reporta la quincena-1 (1..15 de ese mes)', () {
      final p = FortnightCalculator.periodForFireTime(DateTime(2026, 8, 16, hour));
      expect(p.start, DateTime(2026, 8, 1));
      expect(p.end, DateTime(2026, 8, 15));
    });

    test('disparo del día 1 → reporta 16..fin de mes del mes ANTERIOR', () {
      final p = FortnightCalculator.periodForFireTime(DateTime(2026, 9, 1, hour));
      expect(p.start, DateTime(2026, 8, 16));
      expect(p.end, DateTime(2026, 8, 31));
    });

    test('disparo del 1 de enero → reporta 16..31 de DICIEMBRE del año '
        'anterior', () {
      final p = FortnightCalculator.periodForFireTime(DateTime(2026, 1, 1, hour));
      expect(p.start, DateTime(2025, 12, 16));
      expect(p.end, DateTime(2025, 12, 31));
    });
  });

  group('nextFireTime — cadencia fija 1 y 16 a las 20:00 (patrón Fix A)', () {
    test('día 1 antes de las 20:00 → dispara HOY a las 20:00', () {
      final now = DateTime(2026, 8, 1, 8, 0);
      expect(
        FortnightCalculator.nextFireTime(now, hour: hour),
        DateTime(2026, 8, 1, hour, 0),
      );
    });

    test('día 5 → dispara el día 16 a las 20:00', () {
      final now = DateTime(2026, 8, 5, 12, 0);
      expect(
        FortnightCalculator.nextFireTime(now, hour: hour),
        DateTime(2026, 8, 16, hour, 0),
      );
    });

    test('día 16 antes de las 20:00 → dispara HOY a las 20:00 '
        '(reporta la quincena-1)', () {
      final now = DateTime(2026, 8, 16, 8, 0);
      expect(
        FortnightCalculator.nextFireTime(now, hour: hour),
        DateTime(2026, 8, 16, hour, 0),
      );
    });

    test('día 16 después de las 20:00 → dispara el día 1 del mes siguiente', () {
      final now = DateTime(2026, 8, 16, 21, 0);
      expect(
        FortnightCalculator.nextFireTime(now, hour: hour),
        DateTime(2026, 9, 1, hour, 0),
      );
    });

    test('en la hora EXACTA del disparo, el siguiente es estrictamente futuro '
        '(Fix A: nunca al pasado)', () {
      final now = DateTime(2026, 8, 16, hour, 0);
      final next = FortnightCalculator.nextFireTime(now, hour: hour);
      expect(next.isAfter(now), isTrue);
    });

    test('febrero: día 28 → dispara el 1 de marzo', () {
      final now = DateTime(2026, 2, 28, 12, 0);
      expect(
        FortnightCalculator.nextFireTime(now, hour: hour),
        DateTime(2026, 3, 1, hour, 0),
      );
    });

    test('diciembre: día 20 → dispara el 1 de ENERO del año siguiente', () {
      final now = DateTime(2026, 12, 20, 12, 0);
      expect(
        FortnightCalculator.nextFireTime(now, hour: hour),
        DateTime(2027, 1, 1, hour, 0),
      );
    });

    test('21:00 del día 1: el disparo de HOY ya pasó → siguiente, día 16', () {
      final now = DateTime(2026, 8, 1, 21, 0);
      expect(
        FortnightCalculator.nextFireTime(now, hour: hour),
        DateTime(2026, 8, 16, hour, 0),
      );
    });
  });

  group('completedCountIn / badgesUnlockedIn / body canónico', () {
    final period = Fortnight(
      start: DateTime(2026, 8, 1),
      end: DateTime(2026, 8, 15),
    );

    test('completedCountIn cuenta según completedAt dentro del periodo', () {
      final tasks = [
        Task(
          id: 'a',
          title: 'a',
          scheduledDate: DateTime(2026, 8, 1),
          isCompleted: true,
          completedAt: DateTime(2026, 8, 5),
          createdAt: DateTime(2026, 8, 1),
        ),
        Task(
          id: 'b',
          title: 'b',
          scheduledDate: DateTime(2026, 8, 16),
          isCompleted: true,
          completedAt: DateTime(2026, 8, 16),
          createdAt: DateTime(2026, 8, 16),
        ),
        Task(
          id: 'c',
          title: 'c',
          scheduledDate: DateTime(2026, 8, 1),
          createdAt: DateTime(2026, 8, 1),
        ),
      ];
      expect(FortnightCalculator.completedCountIn(tasks, period), 1);
    });

    test('badgesUnlockedIn cuenta según unlockedAt dentro del periodo', () {
      final badges = [
        Badge(
          id: '1',
          type: BadgeType.streak3,
          name: 'n',
          iconName: 'i',
          unlockedAt: DateTime(2026, 8, 10),
        ),
        Badge(
          id: '2',
          type: BadgeType.streak7,
          name: 'n',
          iconName: 'i',
          unlockedAt: DateTime(2026, 8, 20),
        ),
      ];
      expect(FortnightCalculator.badgesUnlockedIn(badges, period), 1);
    });

    test('body canónico incluye todas las cifras', () {
      final stats = FortnightSummaryStats(
        period: period,
        completedCount: 4,
        currentStreak: 3,
        level: 2,
        totalXp: 120,
        badgesUnlockedCount: 2,
      );
      final body = FortnightCalculator.fortnightBody(stats);
      expect(body, contains('01/08 - 15/08'));
      expect(body, contains('4 tareas completadas'));
      expect(body, contains('Racha actual: 3 días'));
      expect(body, contains('Nivel 2 · 120 XP'));
      expect(body, contains('Insignias desbloqueadas: 2'));
    });
  });
}