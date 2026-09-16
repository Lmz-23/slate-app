import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:slate_app/application/providers/now_provider.dart';
import 'package:slate_app/application/providers/player_provider.dart';
import 'package:slate_app/application/providers/streak_provider.dart';
import 'package:slate_app/application/providers/task_provider.dart';
import 'package:slate_app/core/theme/app_theme.dart';
import 'package:slate_app/data/hive/boxes/badges_box.dart';
import 'package:slate_app/data/hive/boxes/player_progress_box.dart';
import 'package:slate_app/data/hive/boxes/streaks_box.dart';
import 'package:slate_app/data/hive/boxes/tasks_box.dart';
import 'package:slate_app/domain/entities/badge.dart' as domain;
import 'package:slate_app/domain/entities/player_profile.dart';
import 'package:slate_app/domain/entities/streak.dart';
import 'package:slate_app/domain/entities/task.dart';
import 'package:slate_app/domain/enums/recurrence_type.dart';
import 'package:slate_app/domain/enums/task_priority.dart';
import 'package:slate_app/presentation/screens/progress/progress_screen.dart';
import 'package:slate_app/presentation/screens/progress/widgets/badge_vault.dart';
import 'package:slate_app/presentation/screens/progress/widgets/monthly_calendar.dart';
import 'package:slate_app/presentation/screens/progress/widgets/player_card.dart';
import 'package:slate_app/presentation/screens/progress/widgets/streak_display.dart';
import 'package:slate_app/presentation/screens/progress/widgets/weekly_progress_section.dart';
import 'package:slate_app/presentation/screens/progress/widgets/daily_summary_row.dart';

/// Dobles de las 4 cajas Hive que necesita `ProgressScreen` completa, SIN
/// Hive real: la pantalla solo LEE los 4 providers (`tasksProvider`,
/// `streakProvider`, `badgesProvider`, `playerProvider`), nunca escribe.
/// Mismo patrón que `test/presentation/screens/home/widgets/daily_progress_card_test.dart`.
class _FixedTasksBox implements TasksBox {
  _FixedTasksBox(this._tasks);
  final List<Task> _tasks;

  @override
  List<Task> getAll() => _tasks;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('No debería invocarse en este test');
}

class _FixedStreaksBox implements StreaksBox {
  _FixedStreaksBox(this._streak);
  final Streak _streak;

  @override
  Streak getStreak() => _streak;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('No debería invocarse en este test');
}

class _FixedBadgesBox implements BadgesBox {
  _FixedBadgesBox(this._badges);
  final List<domain.Badge> _badges;

  @override
  List<domain.Badge> getAll() => _badges;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('No debería invocarse en este test');
}

class _FixedPlayerBox implements PlayerProgressBox {
  _FixedPlayerBox(this._profile);
  final PlayerProfile _profile;

  @override
  PlayerProfile getProfile() => _profile;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('No debería invocarse en este test');
}

final _now = DateTime(2026, 3, 10, 12, 0);

Task _task({required String id, required DateTime date, bool completed = false}) {
  return Task(
    id: id,
    title: 'Tarea $id',
    scheduledDate: date,
    isCompleted: completed,
    priority: TaskPriority.normal,
    recurrence: RecurrenceType.none,
    createdAt: date,
  );
}

Future<void> _pumpProgressScreen(WidgetTester tester) async {
  final container = ProviderContainer(
    overrides: [
      nowProvider.overrideWith((ref) => Stream<DateTime>.value(_now)),
      tasksBoxProvider.overrideWithValue(_FixedTasksBox([
        _task(id: 'a', date: _now, completed: true),
        _task(id: 'b', date: _now, completed: false),
      ])),
      streaksBoxProvider.overrideWithValue(
        _FixedStreaksBox(Streak(id: 'streak', currentStreak: 5, longestStreak: 10, updatedAt: _now)),
      ),
      badgesBoxProvider.overrideWithValue(_FixedBadgesBox(const [])),
      playerProgressBoxProvider.overrideWithValue(
        _FixedPlayerBox(PlayerProfile(id: 'main_player', totalXp: 250, level: 2, updatedAt: _now)),
      ),
    ],
  );
  addTearDown(container.dispose);

  await container.read(nowProvider.future);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const ProgressScreen(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('ProgressScreen - render completo', () {
    testWidgets('renderiza sin excepciones', (tester) async {
      await _pumpProgressScreen(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(ProgressScreen), findsOneWidget);
    });

    testWidgets(
        'los 7 bloques (cabecera, racha, semanal, resumen, calendario, perfil, insignias) '
        'aparecen en el orden esperado (sistema-visual-fase3.md §2)', (tester) async {
      await _pumpProgressScreen(tester);

      // 1. Cabecera.
      expect(find.text('Progreso'), findsOneWidget);
      expect(find.text('Tu constancia esta semana'), findsOneWidget);
      // 2-7: un widget de cada tipo, exactamente una vez.
      expect(find.byType(StreakDisplay), findsOneWidget);
      expect(find.byType(WeeklyProgressSection), findsOneWidget);
      expect(find.byType(DailySummaryRow), findsOneWidget);
      expect(find.byType(MonthlyCalendar), findsOneWidget);
      expect(find.byType(PlayerCard), findsOneWidget);
      expect(find.byType(BadgeVault), findsOneWidget);

      // Orden vertical: cada bloque debe aparecer más abajo (mayor `dy`) que
      // el anterior, en el orden declarado por `ProgressScreen.build`.
      final header = tester.getTopLeft(find.text('Progreso')).dy;
      final streak = tester.getTopLeft(find.byType(StreakDisplay)).dy;
      final weekly = tester.getTopLeft(find.byType(WeeklyProgressSection)).dy;
      final daily = tester.getTopLeft(find.byType(DailySummaryRow)).dy;
      final calendar = tester.getTopLeft(find.byType(MonthlyCalendar)).dy;
      final player = tester.getTopLeft(find.byType(PlayerCard)).dy;
      final badges = tester.getTopLeft(find.byType(BadgeVault)).dy;

      expect(header, lessThan(streak));
      expect(streak, lessThan(weekly));
      expect(weekly, lessThan(daily));
      expect(daily, lessThan(calendar));
      expect(calendar, lessThan(player));
      expect(player, lessThan(badges));
    });

    testWidgets('refleja los datos de los providers en el árbol (racha, nivel)',
        (tester) async {
      await _pumpProgressScreen(tester);

      expect(find.text('5 días seguidos'), findsOneWidget);
      expect(find.text('Nivel 2'), findsOneWidget);
    });
  });
}
