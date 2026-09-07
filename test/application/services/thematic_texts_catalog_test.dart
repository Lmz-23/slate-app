import 'package:flutter_test/flutter_test.dart';

import 'package:slate_app/application/services/reminder_schedule_calculator.dart';
import 'package:slate_app/application/services/thematic_texts_catalog.dart';
import 'package:slate_app/domain/entities/task.dart';
import 'package:slate_app/domain/enums/badge_type.dart';

Task _task(
  String id,
  String title,
  DateTime scheduledDate, {
  DateTime? scheduledTime,
}) {
  return Task(
    id: id,
    title: title,
    scheduledDate: scheduledDate,
    scheduledTime: scheduledTime,
    createdAt: scheduledDate,
  );
}

void main() {
  group('ThematicTextsCatalog - notificaciones', () {
    test('recordatorio de tarea: título "Daily Quest" con glifo ▶', () {
      final task = _task(
        'a',
        'Comprar leche',
        DateTime(2026, 1, 15),
        scheduledTime: DateTime(2026, 1, 15, 14, 0),
      );
      final text = ThematicTextsCatalog.taskReminder(task);

      expect(text.title, contains('▶'));
      expect(text.title, contains('Daily Quest'));
      expect(text.body, contains('Comprar leche'));
      expect(text.body, contains('14:00'));
    });

    test('resumen de la mañana: System Report con singular/plural', () {
      final one = ThematicTextsCatalog.morningSummary(1);
      expect(one.title, contains('◇'));
      expect(one.title, contains('System Report'));
      expect(one.body, contains('1 misión'));

      final many = ThematicTextsCatalog.morningSummary(3);
      expect(many.body, contains('3 misiones'));
    });

    test('resumen de la tarde: Advertencia del Sistema con ⚠', () {
      final text = ThematicTextsCatalog.eveningSummary(2);
      expect(text.title, contains('⚠'));
      expect(text.title, contains('Advertencia del Sistema'));
      expect(text.body, contains('2 misiones'));
    });

    test('cierre de jornada: System Report con racha y hito', () {
      final stats = DayClosureStats(
        jornada: DateTime(2026, 1, 14),
        total: 5,
        completed: 3,
        currentStreak: 7,
        milestone: BadgeType.streak7,
      );
      final text = ThematicTextsCatalog.dayClosure(stats);

      expect(text.title, contains('◆'));
      expect(text.title, contains('System Report'));
      expect(text.body, contains('3/5'));
      expect(text.body, contains('2 pendientes'));
      expect(text.body, contains('7 días'));
      expect(text.body, contains('Rango E · Nivel II'));
    });

    test('cierre de jornada sin hito ni racha omite esas secciones', () {
      final text = ThematicTextsCatalog.dayClosure(
        DayClosureStats(
          jornada: DateTime(2026, 1, 14),
          total: 2,
          completed: 2,
        ),
      );
      expect(text.body, contains('2/2'));
      expect(text.body, isNot(contains('Racha vigente')));
      expect(text.body, isNot(contains('Hito alcanzado')));
    });

    test('alerta de racha en peligro: título y cuerpo exactos (F2)', () {
      final text = ThematicTextsCatalog.streakAtRisk(5);
      expect(text.title, contains('⚠'));
      expect(text.title, contains('Racha en peligro'));
      expect(
        text.body,
        contains('Tu racha de 5 días se perderá si no completas una misión hoy.'),
      );
    });

    test('alerta de racha en peligro: singular con 1 día', () {
      final text = ThematicTextsCatalog.streakAtRisk(1);
      expect(text.body, contains('Tu racha de 1 día se perderá'));
    });

    test('transición "Nivel subió" (SnackBar in-app), glifo ◆', () {
      final message = ThematicTextsCatalog.levelUpMessage(2);
      expect(message, contains('◆'));
      expect(message, contains('Nivel subió'));
      expect(message, contains('Nivel 2'));
    });
  });

  group('ThematicTextsCatalog - claves de caché', () {
    test('taskCacheKey normaliza el título (minúsculas, espacios)', () {
      final task = _task('abc', '  Comprar  Leche ', DateTime(2026, 1, 15));
      final task2 = _task('abc', 'comprar leche', DateTime(2026, 1, 16));

      expect(
        ThematicTextsCatalog.taskCacheKey(task),
        ThematicTextsCatalog.taskCacheKey(task2),
        reason: 'id + título normalizado deben producir la misma clave',
      );
    });

    test('taskCacheKey distingue tareas distintas', () {
      final a = _task('x', 'Tarea A', DateTime(2026, 1, 15));
      final b = _task('x', 'Tarea B', DateTime(2026, 1, 15));
      expect(
        ThematicTextsCatalog.taskCacheKey(a),
        isNot(ThematicTextsCatalog.taskCacheKey(b)),
        reason: 'el título normalizado forma parte de la clave',
      );
    });
  });

  group('ThematicTextsCatalog - nivel/rango de insignias (9 hitos)', () {
    test('la escalera completa sigue las decisiones de producto', () {
      const expected = <BadgeType, String>{
        BadgeType.streak3: 'Rango E · Nivel I',
        BadgeType.streak7: 'Rango E · Nivel II',
        BadgeType.streak14: 'Rango D · Nivel I',
        BadgeType.streak21: 'Rango D · Nivel II',
        BadgeType.streak30: 'Rango C · Nivel I',
        BadgeType.streak60: 'Rango B · Nivel I',
        BadgeType.streak90: 'Rango A · Nivel I',
        BadgeType.streak180: 'Rango S · Nivel I',
        BadgeType.streak365: 'Nivel Nacional',
      };
      for (final entry in expected.entries) {
        expect(
          ThematicTextsCatalog.slateBadgeTitle(entry.key),
          entry.value,
          reason: 'hito ${entry.key.name}',
        );
      }
    });

    test('cada hito tiene apodo (flavor) y un icono sugerido', () {
      for (final type in BadgeType.values) {
        expect(ThematicTextsCatalog.slateBadgeFlavor(type), isNotEmpty);
        expect(ThematicTextsCatalog.slateBadgeIconName(type), isNotEmpty);
      }
      expect(ThematicTextsCatalog.slateBadgeFlavor(BadgeType.streak3),
          'El Despertar');
      expect(
          ThematicTextsCatalog.slateBadgeFlavor(BadgeType.streak365), 'Leyenda');
    });
  });
}