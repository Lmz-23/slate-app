import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:slate_app/application/providers/notification_providers.dart';
import 'package:slate_app/application/providers/now_provider.dart';
import 'package:slate_app/application/providers/player_provider.dart';
import 'package:slate_app/application/providers/quest_auto_claim.dart';
import 'package:slate_app/application/providers/quest_provider.dart';
import 'package:slate_app/application/providers/settings_provider.dart';
import 'package:slate_app/application/providers/task_provider.dart';
import 'package:slate_app/application/services/reminder_manager.dart';
import 'package:slate_app/application/services/reminder_scheduler.dart';
import 'package:slate_app/application/services/timezone_service.dart';
import 'package:slate_app/data/hive/adapters/companion_state_adapter.dart';
import 'package:slate_app/data/hive/adapters/player_profile_adapter.dart';
import 'package:slate_app/data/hive/adapters/task_adapter.dart';
import 'package:slate_app/data/hive/adapters/user_settings_adapter.dart';
import 'package:slate_app/data/hive/boxes/companion_state_box.dart';
import 'package:slate_app/data/hive/boxes/player_progress_box.dart';
import 'package:slate_app/data/hive/boxes/settings_box.dart';
import 'package:slate_app/data/hive/boxes/tasks_box.dart';
import 'package:slate_app/domain/entities/task.dart';
import 'package:slate_app/domain/enums/task_priority.dart';

/// Fake del contrato de bajo nivel (evita el plugin nativo en `flutter test`).
class _FakeScheduler implements ReminderScheduler {
  @override
  Future<void> init({required String timezone}) async {}

  @override
  Future<bool> canScheduleExactNotifications() async => true;

  @override
  Future<bool> requestExactAlarmsPermission() async => true;

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime fireTime,
  }) async {}

  @override
  Future<void> cancel(int id) async {}
}

void main() {
  late Directory tempDir;
  late TasksBox tasksBox;
  late PlayerProgressBox playerBox;
  late CompanionStateBox companionBox;
  late SettingsBox settingsBox;
  late DateTime today;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('slate_quest_auto_claim_test');
    Hive.init(tempDir.path);
    Hive.registerAdapter(TaskAdapter());
    Hive.registerAdapter(PlayerProfileAdapter());
    Hive.registerAdapter(CompanionStateAdapter());
    Hive.registerAdapter(UserSettingsAdapter());
  });

  setUp(() async {
    tasksBox = TasksBox();
    await tasksBox.init();
    playerBox = PlayerProgressBox();
    await playerBox.init();
    companionBox = CompanionStateBox();
    await companionBox.init();
    settingsBox = SettingsBox();
    await settingsBox.init();

    // Ancla de "hoy" con la MISMA función que usa `questProvider` en
    // producción (`TimezoneService.nowInTimezone`), recortada a medianoche
    // LOCAL (mismo patrón que `selectedDateProvider`/`TasksNotifier`, que
    // construyen "hoy" como `DateTime(now.year, now.month, now.day)`, un
    // `DateTime` plano en la zona del dispositivo, no un `TZDateTime` con
    // hora — evita el desfase absoluto entre zonas al comparar contra el
    // guard de "fecha futura" de `toggleComplete`).
    final tzNow = TimezoneService.nowInTimezone(settingsBox.getSettings().timezone);
    today = DateTime(tzNow.year, tzNow.month, tzNow.day);
  });

  tearDown(() async {
    await Hive.close();
    await Hive.deleteBoxFromDisk('tasks');
    await Hive.deleteBoxFromDisk('player_progress');
    await Hive.deleteBoxFromDisk('companion_state');
    await Hive.deleteBoxFromDisk('settings');
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  ProviderContainer createContainer() => ProviderContainer(
        overrides: [
          tasksBoxProvider.overrideWithValue(tasksBox),
          playerProgressBoxProvider.overrideWithValue(playerBox),
          companionStateBoxProvider.overrideWithValue(companionBox),
          settingsBoxProvider.overrideWithValue(settingsBox),
          // `TasksNotifier.toggleComplete` valida contra `nowProvider` (no
          // `TimezoneService` directamente): se fija al MISMO instante `today`
          // usado para sembrar las tareas, para que ambos coincidan siempre en
          // el mismo día calendario sin depender de la zona del sistema donde
          // corre el test.
          nowProvider.overrideWith((ref) => Stream<DateTime>.value(today)),
          reminderManagerProvider.overrideWithValue(
            ReminderManager(scheduler: _FakeScheduler()),
          ),
        ],
      );

  Future<void> seedTasks(int count, {TaskPriority priority = TaskPriority.normal}) async {
    for (var i = 0; i < count; i++) {
      await tasksBox.add(Task(
        id: 'task_$i',
        title: 'Tarea $i',
        scheduledDate: today,
        priority: priority,
        createdAt: today,
      ));
    }
  }

  /// Drena la cadena asíncrona del efecto de auto-reclamo (mismo patrón que
  /// otros tests de este proyecto para operaciones `unawaited`/en segundo
  /// plano).
  Future<void> settle() async {
    for (var i = 0; i < 30; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  int xp() => playerBox.getProfile().totalXp;

  test(
    'con 3 tareas completadas la quest se auto-reclama (+25 XP) SIN invocar '
    'claim() manualmente',
    () async {
      await seedTasks(3);
      final container = createContainer();
      addTearDown(container.dispose);

      // Activa el efecto (equivalente a `ref.watch` en NavigationShell): sin
      // esto la quest no tendría suscriptores (RG15).
      container.read(questAutoClaimProvider);
      // `TasksNotifier.toggleComplete` lee `nowProvider` de forma síncrona
      // (`ref.read(...).value`): hay que esperar a que el stream sobrescrito
      // entregue su primer valor antes de completar tareas, o el guard de
      // "fecha futura" cae al `DateTime.now()` real del dispositivo.
      await container.read(nowProvider.future);

      expect(xp(), 0);
      expect(container.read(questProvider).isClaimed, isFalse);

      final tasksNotifier = container.read(tasksProvider.notifier);
      await tasksNotifier.toggleComplete('task_0');
      await tasksNotifier.toggleComplete('task_1');
      await tasksNotifier.toggleComplete('task_2');
      await settle();

      // 3 tareas de prioridad normal (+10 c/u) + la quest auto-reclamada
      // (+25), sin que el test invoque `claim()` en ningún momento.
      expect(xp(), 30 + 25);
      expect(container.read(questProvider).isClaimed, isTrue);
    },
  );

  test('el auto-reclamo no se duplica en un segundo ciclo', () async {
    await seedTasks(3);
    final container = createContainer();
    addTearDown(container.dispose);
    container.read(questAutoClaimProvider);
    await container.read(nowProvider.future);

    final tasksNotifier = container.read(tasksProvider.notifier);
    await tasksNotifier.toggleComplete('task_0');
    await tasksNotifier.toggleComplete('task_1');
    await tasksNotifier.toggleComplete('task_2');
    await settle();

    final xpAfterFirstClaim = xp();
    expect(xpAfterFirstClaim, 30 + 25);

    // Un segundo ciclo de refresco (p. ej. el reloj avanza, otra tarea
    // cambia) no debe volver a sumar +25: la persistencia
    // (`questClaimedOn == todayKey`) ya lo impide.
    container.read(questProvider.notifier).refresh();
    await settle();

    expect(xp(), xpAfterFirstClaim,
        reason: 'la quest ya reclamada hoy no vuelve a otorgar XP');
  });

  test(
    'questRewardLevelUpProvider recibe el nivel exactamente una vez al cruzar '
    'un nivel nuevo con el auto-reclamo',
    () async {
      // El auto-reclamo dispara en cuanto `completedToday` llega a 3 (el
      // umbral de la quest, ver `QuestCalculator.requiredCompletions`): el XP
      // que "ve" el +25 es el acumulado hasta ESE instante, no el de
      // completaciones posteriores. Para que la QUEST (y no una tarea) sea la
      // que cruce el nivel 2 (100 XP), se parte de una base de 50 XP (una
      // sesión anterior) + 3 tareas normales (+10 c/u = 30) = 80 (< 100, sin
      // level-up todavía) y el +25 de la quest la lleva a 105.
      await playerBox.updateProfile(playerBox.getProfile().copyWith(
        totalXp: 50,
        level: 1,
      ));
      await seedTasks(3);
      final container = createContainer();
      addTearDown(container.dispose);
      container.read(questAutoClaimProvider);
      await container.read(nowProvider.future);

      final tasksNotifier = container.read(tasksProvider.notifier);
      await tasksNotifier.toggleComplete('task_0');
      await tasksNotifier.toggleComplete('task_1');
      await tasksNotifier.toggleComplete('task_2');
      await settle();

      expect(xp(), 50 + 30 + 25);
      expect(playerBox.getProfile().level, 2);
      expect(container.read(questRewardLevelUpProvider), 2);

      // Un segundo refresco no debe volver a emitir el evento (la quest ya
      // está reclamada; el canal solo cambiaría ante un level-up NUEVO).
      container.read(questProvider.notifier).refresh();
      await settle();
      expect(container.read(questRewardLevelUpProvider), 2);
    },
  );
}
