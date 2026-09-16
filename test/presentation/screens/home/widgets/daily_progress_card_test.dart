import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:slate_app/application/providers/now_provider.dart';
import 'package:slate_app/application/providers/streak_provider.dart';
import 'package:slate_app/application/providers/task_provider.dart';
import 'package:slate_app/core/theme/app_theme.dart';
import 'package:slate_app/data/hive/boxes/badges_box.dart';
import 'package:slate_app/data/hive/boxes/streaks_box.dart';
import 'package:slate_app/data/hive/boxes/tasks_box.dart';
import 'package:slate_app/data/repositories/badge_repository_impl.dart';
import 'package:slate_app/data/repositories/streak_repository_impl.dart';
import 'package:slate_app/domain/entities/badge.dart' as domain;
import 'package:slate_app/domain/entities/streak.dart';
import 'package:slate_app/domain/entities/task.dart';
import 'package:slate_app/domain/enums/recurrence_type.dart';
import 'package:slate_app/domain/enums/task_priority.dart';
import 'package:slate_app/presentation/screens/home/widgets/daily_progress_card.dart';
import 'package:slate_app/presentation/screens/home/widgets/daily_progress_bar.dart';
import 'package:slate_app/presentation/screens/home/widgets/week_activity_row.dart';
import 'package:slate_app/presentation/screens/home/widgets/streak_header_row.dart';

/// Doble de [TasksBox] SIN Hive real: `DailyProgressCard` y sus hijos solo
/// LEEN `tasksProvider` (nunca escriben), así que basta con que `getAll()`
/// devuelva una lista fija. Evita el I/O real de Hive (y la trampa de
/// `testWidgets`/FakeAsync que exige `tester.runAsync` para I/O real) por
/// completo.
class _FixedTasksBox implements TasksBox {
  _FixedTasksBox(this._tasks);
  final List<Task> _tasks;

  @override
  List<Task> getAll() => _tasks;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('No debería invocarse en este test');
}

/// Dobles de [StreaksBox]/[BadgesBox] SIN Hive real: solo se necesita que
/// `streakProvider` exponga una racha fija; ningún test de este archivo
/// desbloquea insignias.
class _FixedStreaksBox implements StreaksBox {
  _FixedStreaksBox(this._streak);
  final Streak _streak;

  @override
  Streak getStreak() => _streak;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('No debería invocarse en este test');
}

class _EmptyBadgesBox implements BadgesBox {
  @override
  List<domain.Badge> getAll() => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('No debería invocarse en este test');
}

/// Doble de [StreakNotifier] con racha FIJA, construido sobre repositorios
/// REALES respaldados por cajas falsas (evita el I/O de Hive por completo).
class _FixedStreakNotifier extends StreakNotifier {
  _FixedStreakNotifier(Streak streak)
      : super(
          StreakRepositoryImpl(_FixedStreaksBox(streak)),
          BadgesNotifier(BadgeRepositoryImpl(_EmptyBadgesBox())),
        ) {
    state = streak;
  }
}

Task _task({
  required String id,
  required DateTime date,
  DateTime? time,
  bool completed = false,
  DateTime? completedAt,
}) {
  return Task(
    id: id,
    title: 'Tarea $id',
    scheduledDate: date,
    scheduledTime: time,
    isCompleted: completed,
    // `QuestCalculator.completedCountOn` (usado por `dailyProgressProvider`)
    // cuenta por `completedAt` (el instante REAL de marcado), NO por
    // `scheduledDate`: una tarea completada sin `completedAt` en el mismo día
    // no cuenta como "completada hoy".
    completedAt: completed ? (completedAt ?? date) : null,
    priority: TaskPriority.normal,
    recurrence: RecurrenceType.none,
    createdAt: date,
  );
}

final _now = DateTime(2026, 3, 10, 9, 0); // martes

Future<void> _pumpCard(
  WidgetTester tester, {
  required List<Task> tasks,
  int currentStreak = 3,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tasksBoxProvider.overrideWithValue(_FixedTasksBox(tasks)),
        nowProvider.overrideWith((ref) => Stream<DateTime>.value(_now)),
        streakProvider.overrideWith(
          (ref) => _FixedStreakNotifier(
            Streak(id: 'streak', currentStreak: currentStreak, updatedAt: _now),
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(body: DailyProgressCard()),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('DailyProgressCard - render básico', () {
    testWidgets('renderiza sin crashear con datos de ejemplo (racha, progreso, semana)',
        (tester) async {
      await _pumpCard(
        tester,
        tasks: [
          _task(id: 'a', date: _now, completed: true),
          _task(id: 'b', date: _now, completed: false),
        ],
        currentStreak: 5,
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(DailyProgressCard), findsOneWidget);
      expect(find.byType(StreakHeaderRow), findsOneWidget);
      expect(find.byType(DailyProgressBar), findsOneWidget);
      expect(find.byType(WeekActivityRow), findsOneWidget);
      expect(find.text('5 días seguidos'), findsOneWidget);
    });

    testWidgets(
        'racha de 1 día: concordancia singular correcta ("1 día seguido")',
        (tester) async {
      await _pumpCard(tester, tasks: [], currentStreak: 1);
      // Fase 3a: corregido el defecto de concordancia — "seguido" ahora
      // pluraliza junto con "día" en vez de ser un sufijo fijo en plural.
      expect(find.text('1 día seguido'), findsOneWidget);
      expect(find.text('1 día seguidos'), findsNothing);
    });
  });

  group('DailyProgressBar - meta diaria', () {
    testWidgets('con tareas pendientes muestra "N de M tareas completadas hoy"',
        (tester) async {
      await _pumpCard(
        tester,
        tasks: [
          _task(id: 'a', date: _now, completed: true),
          _task(id: 'b', date: _now, completed: false),
          _task(id: 'c', date: _now, completed: false),
        ],
      );

      expect(find.text('1 de 3 tareas completadas hoy'), findsOneWidget);
      expect(find.text('Meta diaria cumplida'), findsNothing);
    });

    testWidgets('con todas las tareas de hoy completadas muestra "Meta diaria cumplida"',
        (tester) async {
      await _pumpCard(
        tester,
        tasks: [
          _task(id: 'a', date: _now, completed: true),
          _task(id: 'b', date: _now, completed: true),
        ],
      );

      expect(find.text('Meta diaria cumplida'), findsOneWidget);
      expect(find.text('2 de 2 tareas completadas hoy'), findsNothing);
      // El check visual de meta cumplida (icono de éxito).
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('sin ninguna tarea programada hoy NO se considera meta cumplida '
        '(evita falso positivo con 0 de 0)', (tester) async {
      await _pumpCard(tester, tasks: []);

      expect(find.text('Meta diaria cumplida'), findsNothing);
      expect(find.text('0 de 0 tareas completadas hoy'), findsOneWidget);
    });

    testWidgets('tareas de OTRO día no cuentan para el progreso de hoy', (tester) async {
      final otroDia = _now.subtract(const Duration(days: 3));
      await _pumpCard(
        tester,
        tasks: [
          _task(id: 'a', date: otroDia, completed: true),
          _task(id: 'b', date: _now, completed: false),
        ],
      );

      expect(find.text('0 de 1 tareas completadas hoy'), findsOneWidget);
    });
  });
}
