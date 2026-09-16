import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:slate_app/application/providers/now_provider.dart';
import 'package:slate_app/application/providers/player_provider.dart';
import 'package:slate_app/application/providers/quest_provider.dart';
import 'package:slate_app/application/providers/settings_provider.dart';
import 'package:slate_app/application/providers/streak_provider.dart';
import 'package:slate_app/application/providers/task_provider.dart';
import 'package:slate_app/core/theme/app_theme.dart';
import 'package:slate_app/data/hive/adapters/badge_adapter.dart';
import 'package:slate_app/data/hive/adapters/companion_state_adapter.dart';
import 'package:slate_app/data/hive/adapters/player_profile_adapter.dart';
import 'package:slate_app/data/hive/adapters/streak_adapter.dart';
import 'package:slate_app/data/hive/adapters/task_adapter.dart';
import 'package:slate_app/data/hive/adapters/user_settings_adapter.dart';
import 'package:slate_app/data/hive/boxes/badges_box.dart';
import 'package:slate_app/data/hive/boxes/companion_state_box.dart';
import 'package:slate_app/data/hive/boxes/player_progress_box.dart';
import 'package:slate_app/data/hive/boxes/settings_box.dart';
import 'package:slate_app/data/hive/boxes/streaks_box.dart';
import 'package:slate_app/data/hive/boxes/tasks_box.dart';
import 'package:slate_app/presentation/navigation/app_router.dart';
import 'package:slate_app/presentation/screens/home/home_screen.dart';
import 'package:slate_app/presentation/screens/progress/progress_screen.dart';
import 'package:slate_app/presentation/screens/settings/settings_screen.dart';
import 'package:slate_app/presentation/widgets/common/navigation_shell.dart';

/// Réplica MÍNIMA de las cajas Hive reales que necesita el árbol completo de
/// pantallas montado por `appRouter` (Home + NavigationShell + Progress):
/// `TasksNotifier`, `SettingsNotifier`, `PlayerNotifier`, `StreakNotifier`,
/// `BadgesNotifier` y `QuestNotifier` (vía `CompanionStateBox`) leen su caja
/// de forma SÍNCRONA al construirse, así que hace falta abrirlas de verdad
/// (Hive real en un directorio temporal) para que el primer build no lance
/// `UnimplementedError`. Mismo patrón que
/// `test/application/providers/task_provider_recurring_reminders_test.dart`.
///
/// IMPORTANTE (ver `.claude/agent-memory/tester/flutter_widget_test_gotchas.md`):
/// `QuestNotifier._sync()` (invocado en su constructor, disparado por
/// `NavigationShell` al observar `questAutoClaimProvider`) lanza un
/// `_repository.updateState(...)` SIN esperar (fire-and-forget) la primera
/// vez que `companion.questVisibleOn != todayKey` — lo cual es SIEMPRE en un
/// box recién creado. Si el primer `pumpWidget`/`pump` que dispara esa
/// cascada no corre dentro de `tester.runAsync`, ese `Future` real queda
/// colgado en la zona `FakeAsync` para siempre y se lleva consigo el lock de
/// escritura de Hive: el `Hive.close()` del `tearDown` (zona real) se
/// bloquea esperando ese lock indefinidamente (cuelgue permanente, no solo
/// lento). Por eso TODO el montaje inicial va dentro de `runAsync` aquí.
void main() {
  late Directory tempDir;
  late TasksBox tasksBox;
  late SettingsBox settingsBox;
  late PlayerProgressBox playerProgressBox;
  late StreaksBox streaksBox;
  late BadgesBox badgesBox;
  late CompanionStateBox companionStateBox;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('slate_app_router_test');
    Hive.init(tempDir.path);
    Hive.registerAdapter(TaskAdapter());
    Hive.registerAdapter(UserSettingsAdapter());
    Hive.registerAdapter(PlayerProfileAdapter());
    Hive.registerAdapter(StreakAdapter());
    Hive.registerAdapter(BadgeAdapter());
    Hive.registerAdapter(CompanionStateAdapter());
  });

  setUp(() async {
    tasksBox = TasksBox();
    await tasksBox.init();
    settingsBox = SettingsBox();
    await settingsBox.init();
    playerProgressBox = PlayerProgressBox();
    await playerProgressBox.init();
    streaksBox = StreaksBox();
    await streaksBox.init();
    badgesBox = BadgesBox();
    await badgesBox.init();
    companionStateBox = CompanionStateBox();
    await companionStateBox.init();
  });

  tearDown(() async {
    await Hive.close();
    await Hive.deleteBoxFromDisk('tasks');
    await Hive.deleteBoxFromDisk('settings');
    await Hive.deleteBoxFromDisk('player_progress');
    await Hive.deleteBoxFromDisk('streaks');
    await Hive.deleteBoxFromDisk('badges');
    await Hive.deleteBoxFromDisk('companion_state');
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  /// Monta el `appRouter` real (Decisión A10) con las 6 cajas por override,
  /// exactamente como lo hace `main.dart` en producción (sin pasar por
  /// `SlateApp`/`dailyReminderControllerProvider`, que es responsabilidad de
  /// `app.dart`, no de `app_router.dart`), y drena la escritura real de
  /// `CompanionStateBox` disparada por `QuestNotifier._sync()` (ver nota de
  /// cabecera) antes de salir de `runAsync`.
  Future<void> pumpRouter(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // `nowProvider` real usa un `Timer.periodic` de 30s: dentro de
            // la zona `FakeAsync` de `testWidgets`, cada tick reprograma un
            // nuevo frame y `pumpAndSettle()` nunca "settlea" (cuelgue
            // indefinido). Se fija a un único valor, igual que en
            // `monthly_calendar_test.dart`.
            nowProvider.overrideWith(
              (ref) => Stream<DateTime>.value(DateTime(2026, 3, 10, 12, 0)),
            ),
            tasksBoxProvider.overrideWithValue(tasksBox),
            settingsBoxProvider.overrideWithValue(settingsBox),
            playerProgressBoxProvider.overrideWithValue(playerProgressBox),
            streaksBoxProvider.overrideWithValue(streaksBox),
            badgesBoxProvider.overrideWithValue(badgesBox),
            companionStateBoxProvider.overrideWithValue(companionStateBox),
          ],
          child: MaterialApp.router(
            theme: AppTheme.darkTheme,
            routerConfig: appRouter,
          ),
        ),
      );
      // Drena el `updateState` fire-and-forget de `QuestNotifier._sync()`
      // con pequeños delays reales + `pump()` (mismo patrón que
      // `task_form_conflict_dialog_test.dart`).
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
      }
    });
  }

  /// Navega con `appRouter.go` dentro de `runAsync`: la reconstrucción del
  /// árbol de destino dispara la MISMA cascada de `QuestNotifier` que el
  /// montaje inicial.
  Future<void> goAndDrain(WidgetTester tester, String location) async {
    await tester.runAsync(() async {
      appRouter.go(location);
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
      }
    });
  }

  group('appRouter - Decisión A10 (fusión Weekly+Stats)', () {
    testWidgets('arranca en /home mostrando HomeScreen dentro del shell',
        (tester) async {
      await pumpRouter(tester);
      await tester.pumpAndSettle();

      expect(appRouter.routerDelegate.currentConfiguration.uri.path, '/home');
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(NavigationShell), findsOneWidget);
    });

    testWidgets('/weekly redirige a /progress y renderiza ProgressScreen',
        (tester) async {
      await pumpRouter(tester);
      await tester.pumpAndSettle();

      await goAndDrain(tester, '/weekly');
      await tester.pumpAndSettle();

      expect(
        appRouter.routerDelegate.currentConfiguration.uri.path,
        '/progress',
        reason: 'A10: /weekly debe redirigir a /progress',
      );
      expect(find.byType(ProgressScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('/stats redirige a /progress y renderiza ProgressScreen',
        (tester) async {
      await pumpRouter(tester);
      await tester.pumpAndSettle();

      await goAndDrain(tester, '/stats');
      await tester.pumpAndSettle();

      expect(
        appRouter.routerDelegate.currentConfiguration.uri.path,
        '/progress',
        reason: 'A10: /stats debe redirigir a /progress',
      );
      expect(find.byType(ProgressScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets(
        'rutas no relacionadas (/settings) no se ven afectadas por el redirect',
        (tester) async {
      await pumpRouter(tester);
      await tester.pumpAndSettle();

      await goAndDrain(tester, '/settings');
      await tester.pumpAndSettle();

      expect(
        appRouter.routerDelegate.currentConfiguration.uri.path,
        '/settings',
      );
      expect(find.byType(SettingsScreen), findsOneWidget);
    });
  });
}
