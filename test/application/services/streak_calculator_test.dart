import 'package:flutter_test/flutter_test.dart';

import 'package:slate_app/application/services/streak_calculator.dart';
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

/// Fecha local (así la guarda la app en `scheduledDate`).
DateTime _d(int y, int m, int d) => DateTime(y, m, d);

/// Día esperado en `lastCompletedDate` (medianoche UTC).
DateTime _day(int y, int m, int d) => DateTime.utc(y, m, d);

/// Instante "ahora" en la zona configurada (local).
DateTime _now(int y, int m, int d, [int h = 12, int min = 0]) =>
    DateTime(y, m, d, h, min);

void main() {
  group('StreakCalculator.calculate', () {
    test('sin tareas completadas: racha 0, longest 0 y sin último día', () {
      final result = StreakCalculator.calculate(
        tasks: const [],
        now: _now(2026, 1, 14),
      );

      expect(result.currentStreak, 0);
      expect(result.longestStreak, 0);
      expect(result.lastCompletedDate, isNull);
      expect(result.activeDays, isEmpty);
    });

    test('secuencial normal: lunes→martes→miércoles suma 3', () {
      final result = StreakCalculator.calculate(
        tasks: [
          _task('a', _d(2026, 1, 12)), // lunes
          _task('b', _d(2026, 1, 13)), // martes
          _task('c', _d(2026, 1, 14)), // miércoles
        ],
        now: _now(2026, 1, 14),
      );

      expect(result.currentStreak, 3);
      expect(result.longestStreak, 3);
      expect(result.lastCompletedDate, _day(2026, 1, 14));
    });

    test('hueco rompe la racha actual pero longestStreak conserva el máximo', () {
      // Historial previo ya tenía una racha de 2 (p. ej. lunes+martes antes
      // de desmarcar martes). Ahora solo lunes y miércoles están activos.
      final result = StreakCalculator.calculate(
        tasks: [
          _task('a', _d(2026, 1, 12)), // lunes
          _task('c', _d(2026, 1, 14)), // miércoles
        ],
        now: _now(2026, 1, 14),
        previousLongestStreak: 2,
      );

      expect(result.currentStreak, 1); // anclada en miércoles, martes falta
      expect(result.longestStreak, 2); // el máximo histórico no baja
      expect(result.lastCompletedDate, _day(2026, 1, 14));
    });

    test('el máximo histórico se deriva del historial aunque la actual sea menor', () {
      // lunes+martes (racha 2) y jueves (ancla). El hueco del miércoles deja
      // la racha actual en 1, pero el historial conserva la racha de 2.
      final result = StreakCalculator.calculate(
        tasks: [
          _task('a', _d(2026, 1, 12)), // lunes
          _task('b', _d(2026, 1, 13)), // martes
          _task('d', _d(2026, 1, 15)), // jueves
        ],
        now: _now(2026, 1, 15),
        previousLongestStreak: 0,
      );

      expect(result.currentStreak, 1);
      expect(result.longestStreak, 2);
    });

    test('ayer después de hoy (R2a): completar martes después de miércoles suma ambos', () {
      // Paso 1: solo la tarea de hoy (miércoles) está completada.
      final step1 = StreakCalculator.calculate(
        tasks: [
          _task('wed', _d(2026, 1, 14)),
        ],
        now: _now(2026, 1, 14),
      );
      expect(step1.currentStreak, 1);

      // Paso 2: se completa además la tarea de ayer (martes). El recálculo
      // derivado suma ayer aunque "hoy" ya estaba marcado.
      final step2 = StreakCalculator.calculate(
        tasks: [
          _task('wed', _d(2026, 1, 14)),
          _task('tue', _d(2026, 1, 13)),
        ],
        now: _now(2026, 1, 14),
      );
      expect(step2.currentStreak, 2);
      expect(step2.longestStreak, 2);
      expect(step2.lastCompletedDate, _day(2026, 1, 14));
    });

    test('desmarcar baja la racha (R3b) y longestStreak nunca baja', () {
      // Estado inicial: lunes, martes y miércoles completados → racha 3.
      final initial = StreakCalculator.calculate(
        tasks: [
          _task('a', _d(2026, 1, 12)),
          _task('b', _d(2026, 1, 13)),
          _task('c', _d(2026, 1, 14)),
        ],
        now: _now(2026, 1, 14),
      );
      expect(initial.currentStreak, 3);
      expect(initial.longestStreak, 3);

      // Desmarcar miércoles (el ancla): la racha baja a 2, el máximo se conserva.
      final step2 = StreakCalculator.calculate(
        tasks: [
          _task('a', _d(2026, 1, 12)),
          _task('b', _d(2026, 1, 13)),
          _task('c', _d(2026, 1, 14), isCompleted: false),
        ],
        now: _now(2026, 1, 14),
        previousLongestStreak: initial.longestStreak,
      );
      expect(step2.currentStreak, 2);
      expect(step2.longestStreak, 3);

      // Desmarcar también martes: la racha baja a 1, el máximo se conserva.
      final step3 = StreakCalculator.calculate(
        tasks: [
          _task('a', _d(2026, 1, 12)),
          _task('b', _d(2026, 1, 13), isCompleted: false),
          _task('c', _d(2026, 1, 14), isCompleted: false),
        ],
        now: _now(2026, 1, 14),
        previousLongestStreak: step2.longestStreak,
      );
      expect(step3.currentStreak, 1);
      expect(step3.longestStreak, 3);

      // Desmarcar todo: racha 0 y el último día completado se limpia.
      final step4 = StreakCalculator.calculate(
        tasks: [
          _task('a', _d(2026, 1, 12), isCompleted: false),
          _task('b', _d(2026, 1, 13), isCompleted: false),
          _task('c', _d(2026, 1, 14), isCompleted: false),
        ],
        now: _now(2026, 1, 14),
        previousLongestStreak: step3.longestStreak,
      );
      expect(step4.currentStreak, 0);
      expect(step4.longestStreak, 3);
      expect(step4.lastCompletedDate, isNull);
    });

    test('tarea futura cuenta como hoy (clamp R1a)', () {
      // Hoy es miércoles 14. Hay una tarea completada el lunes (pasada) y dos
      // tareas con fecha FUTURA (jueves 15 y 20): ambas se acreditan como hoy.
      final result = StreakCalculator.calculate(
        tasks: [
          _task('mon', _d(2026, 1, 12)),
          _task('future1', _d(2026, 1, 15)),
          _task('future2', _d(2026, 1, 20)),
        ],
        now: _now(2026, 1, 14),
      );

      // Días activos: lunes 12 y hoy 14 (las futuras hacen clamp a hoy).
      expect(result.activeDays, {_day(2026, 1, 12), _day(2026, 1, 14)});
      expect(result.currentStreak, 1); // hueco del martes 13
      expect(result.longestStreak, 1);
    });

    test('solo tareas futuras completadas: todas se acreditan como hoy', () {
      final result = StreakCalculator.calculate(
        tasks: [
          _task('future1', _d(2026, 1, 15)),
          _task('future2', _d(2026, 1, 20)),
        ],
        now: _now(2026, 1, 14),
      );

      expect(result.activeDays, {_day(2026, 1, 14)});
      expect(result.currentStreak, 1);
      expect(result.longestStreak, 1);
    });

    test('normalización de día: se ignora la hora del día en scheduledDate', () {
      // Una tarea de ayer a las 23:59 y una de hoy a las 00:01 pertenecen a
      // días calendario distintos y consecutivos → racha 2.
      final result = StreakCalculator.calculate(
        tasks: [
          _task('late-yesterday', DateTime(2026, 1, 13, 23, 59)),
          _task('early-today', DateTime(2026, 1, 14, 0, 1)),
        ],
        now: _now(2026, 1, 14, 23, 59),
      );

      expect(result.activeDays, {_day(2026, 1, 13), _day(2026, 1, 14)});
      expect(result.currentStreak, 2);
      expect(result.lastCompletedDate, _day(2026, 1, 14));
    });

    test('zona horaria: la normalización es por componentes, no por toUtc()', () {
      // El calculador NO debe convertir a UTC con toUtc() (desplazaría el día
      // en husos negativos): usa año/mes/día del DateTime en la zona configurada.
      // Ahora = 14 de enero 00:30 local; tarea completada 14 de enero 00:30.
      final result = StreakCalculator.calculate(
        tasks: [
          _task('same-day', DateTime(2026, 1, 14, 0, 30)),
        ],
        now: _now(2026, 1, 14, 0, 30),
      );

      expect(result.activeDays, {_day(2026, 1, 14)});
      expect(result.currentStreak, 1);
      expect(result.lastCompletedDate, _day(2026, 1, 14));
    });

    test('tareas pendientes no aportan días activos', () {
      final result = StreakCalculator.calculate(
        tasks: [
          _task('done', _d(2026, 1, 14)),
          _task('pending', _d(2026, 1, 13), isCompleted: false),
          _task('pending2', _d(2026, 1, 12), isCompleted: false),
        ],
        now: _now(2026, 1, 14),
      );

      expect(result.activeDays, {_day(2026, 1, 14)});
      expect(result.currentStreak, 1);
      expect(result.longestStreak, 1);
    });

    test('una subtarea completada NO activa la racha (H2 regla de producto)',
        () {
      // Solo una subtarea completada HOY → no hay ningún día activo.
      final subOnly = StreakCalculator.calculate(
        tasks: [
          Task(
            id: 's1',
            title: 'Subtarea',
            scheduledDate: _d(2026, 1, 14),
            isCompleted: true,
            completedAt: _d(2026, 1, 14),
            createdAt: _d(2026, 1, 14),
            parentTaskId: 'main',
            isSubtask: true,
          ),
        ],
        now: _now(2026, 1, 14),
      );

      expect(subOnly.activeDays, isEmpty);
      expect(subOnly.currentStreak, 0);
      expect(subOnly.lastCompletedDate, isNull);

      // La PRINCIPAL completada (con su subtarea arrastrada) SÍ activa el día:
      // la subtarea no añade ni quita nada respecto a la principal.
      final withMain = StreakCalculator.calculate(
        tasks: [
          _task('main', _d(2026, 1, 14)),
          Task(
            id: 's1',
            title: 'Subtarea',
            scheduledDate: _d(2026, 1, 14),
            isCompleted: true,
            completedAt: _d(2026, 1, 14),
            createdAt: _d(2026, 1, 14),
            parentTaskId: 'main',
            isSubtask: true,
          ),
        ],
        now: _now(2026, 1, 14),
      );

      expect(withMain.activeDays, {_day(2026, 1, 14)});
      expect(withMain.currentStreak, 1);
    });

    test('5 subtareas completadas en 5 días consecutivos NO producen racha',
        () {
      // Verifica la regla a ESCALA: ni siquiera 5 subtareas en 5 días seguidos
      // deben activar la racha (porque las subtareas no son "misiones" del
      // Slate System, solo sub-bloques de una tarea).
      final tasks = [
        for (var day = 10; day <= 14; day++)
          Task(
            id: 's$day',
            title: 'Sub',
            scheduledDate: _d(2026, 1, day),
            isCompleted: true,
            completedAt: _d(2026, 1, day),
            createdAt: _d(2026, 1, day),
            parentTaskId: 'main',
            isSubtask: true,
          ),
      ];
      final result = StreakCalculator.calculate(
        tasks: tasks,
        now: _now(2026, 1, 14),
      );

      expect(result.activeDays, isEmpty,
          reason: 'ningún día con solo subtareas cuenta como activo');
      expect(result.currentStreak, 0);
      expect(result.lastCompletedDate, isNull);
    });

    test(
        '1 principal con 3 subtareas por día, 5 días seguidos: racha 5 (la '
        'sub no aporta, solo la principal)', () {
      // Caso simétrico: con principale+subs la racha sigue valiendo 5, no
      // 5×(1+3) = 20. La subtarea arrastrada no añade ni quita.
      final tasks = <Task>[];
      for (var day = 10; day <= 14; day++) {
        tasks.add(_task('main', _d(2026, 1, day)));
        for (var sub = 1; sub <= 3; sub++) {
          tasks.add(Task(
            id: 's${day}_$sub',
            title: 'Sub',
            scheduledDate: _d(2026, 1, day),
            isCompleted: true,
            completedAt: _d(2026, 1, day),
            createdAt: _d(2026, 1, day),
            parentTaskId: 'main',
            isSubtask: true,
          ));
        }
      }
      final result = StreakCalculator.calculate(
        tasks: tasks,
        now: _now(2026, 1, 14),
      );

      expect(result.activeDays, {
        _day(2026, 1, 10),
        _day(2026, 1, 11),
        _day(2026, 1, 12),
        _day(2026, 1, 13),
        _day(2026, 1, 14),
      });
      expect(result.currentStreak, 5);
      expect(result.longestStreak, 5);
    });
  });

  group('BadgeType.badgesUpTo (desbloqueo multi-umbral)', () {
    test('sin racha o racha por debajo del primer umbral: nada', () {
      expect(BadgeType.badgesUpTo(0), isEmpty);
      expect(BadgeType.badgesUpTo(2), isEmpty);
    });

    test('salto de varios días desbloquea TODOS los umbrales intermedios', () {
      expect(BadgeType.badgesUpTo(3), [BadgeType.streak3]);
      expect(BadgeType.badgesUpTo(7), [BadgeType.streak3, BadgeType.streak7]);
      expect(
        BadgeType.badgesUpTo(14),
        [BadgeType.streak3, BadgeType.streak7, BadgeType.streak14],
      );
      expect(
        BadgeType.badgesUpTo(30),
        [
          BadgeType.streak3,
          BadgeType.streak7,
          BadgeType.streak14,
          BadgeType.streak21,
          BadgeType.streak30,
        ],
      );
    });

    test('a partir de 365 días se cubren las 9 insignias', () {
      final all = BadgeType.badgesUpTo(365);
      expect(all, hasLength(9));
      expect(all.first, BadgeType.streak3);
      expect(all.last, BadgeType.streak365);
    });

    test('los umbrales están en orden ascendente', () {
      final days = BadgeType.badgesUpTo(365).map((b) => b.requiredDays).toList();
      for (var i = 1; i < days.length; i++) {
        expect(days[i], greaterThan(days[i - 1]));
      }
    });
  });
}
