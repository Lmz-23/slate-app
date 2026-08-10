import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:slate_app/application/providers/notification_providers.dart';
import 'package:slate_app/application/providers/player_provider.dart';
import 'package:slate_app/application/providers/settings_provider.dart';
import 'package:slate_app/application/providers/streak_provider.dart';
import 'package:slate_app/application/providers/task_provider.dart';
import 'package:slate_app/application/services/notification_ids.dart';
import 'package:slate_app/application/services/reminder_manager.dart';
import 'package:slate_app/application/services/reminder_scheduler.dart';
import 'package:slate_app/data/hive/adapters/badge_adapter.dart';
import 'package:slate_app/data/hive/adapters/player_profile_adapter.dart';
import 'package:slate_app/data/hive/adapters/streak_adapter.dart';
import 'package:slate_app/data/hive/adapters/task_adapter.dart';
import 'package:slate_app/data/hive/adapters/user_settings_adapter.dart';
import 'package:slate_app/data/hive/boxes/badges_box.dart';
import 'package:slate_app/data/hive/boxes/player_progress_box.dart';
import 'package:slate_app/data/hive/boxes/settings_box.dart';
import 'package:slate_app/data/hive/boxes/streaks_box.dart';
import 'package:slate_app/data/hive/boxes/tasks_box.dart';
import 'package:slate_app/domain/entities/task.dart';
import 'package:slate_app/domain/entities/streak.dart';

bool _adaptersRegistered = false;

/// Registra una sola vez los adapters Hive del test (compartidos entre grupos).
void _registerHiveAdapters() {
  if (_adaptersRegistered) return;
  Hive.registerAdapter(TaskAdapter());
  Hive.registerAdapter(UserSettingsAdapter());
  Hive.registerAdapter(StreakAdapter());
  Hive.registerAdapter(BadgeAdapter());
  Hive.registerAdapter(PlayerProfileAdapter());
  _adaptersRegistered = true;
}

/// Fake del contrato de bajo nivel que reproduce el comportamiento del plugin
/// real (`flutter_local_notifications.zonedSchedule`): lanza `ArgumentError`
/// cuando se le pide programar una fecha YA pasada. Es exactamente el error que
/// el Verifier observó como causa de que el cierre de jornada (0x60000003) no
/// se programara.
class ControllerFakeScheduler implements ReminderScheduler {
  final scheduled = <int, ({DateTime fireTime, String title, String body})>{};
  final cancelled = <int>[];

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
  }) async {
    if (!fireTime.isAfter(DateTime.now())) {
      throw ArgumentError('fireTime must be in the future');
    }
    scheduled[id] = (fireTime: fireTime, title: title, body: body);
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    scheduled.remove(id);
  }
}

void main() {
  group('DailyReminderController - regresión Verifier '
      '(una tarea pasada no impide programar el cierre de jornada)', () {
    late Directory tempDir;
    late SettingsBox settingsBox;
    late TasksBox tasksBox;
    late StreaksBox streaksBox;
    late BadgesBox badgesBox;
    late PlayerProgressBox playerProgressBox;
    late ControllerFakeScheduler scheduler;
    late ProviderContainer container;

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('slate_controller_test');
      Hive.init(tempDir.path);
      _registerHiveAdapters();
    });

    setUp(() async {
      settingsBox = SettingsBox();
      await settingsBox.init();
      tasksBox = TasksBox();
      await tasksBox.init();
      streaksBox = StreaksBox();
      await streaksBox.init();
      badgesBox = BadgesBox();
      await badgesBox.init();
      playerProgressBox = PlayerProgressBox();
      await playerProgressBox.init();

      scheduler = ControllerFakeScheduler();
      container = ProviderContainer(
        overrides: [
          settingsBoxProvider.overrideWithValue(settingsBox),
          tasksBoxProvider.overrideWithValue(tasksBox),
          streaksBoxProvider.overrideWithValue(streaksBox),
          badgesBoxProvider.overrideWithValue(badgesBox),
          playerProgressBoxProvider.overrideWithValue(playerProgressBox),
          reminderManagerProvider.overrideWithValue(
            ReminderManager(scheduler: scheduler),
          ),
        ],
      );
      addTearDown(container.dispose);
    });

    tearDown(() async {
      await Hive.close();
      await Hive.deleteBoxFromDisk('settings');
      await Hive.deleteBoxFromDisk('tasks');
      await Hive.deleteBoxFromDisk('streaks');
      await Hive.deleteBoxFromDisk('badges');
      await Hive.deleteBoxFromDisk('player_progress');
    });

    tearDownAll(() async {
      await tempDir.delete(recursive: true);
    });

    /// Espera a que drenen las cadenas asíncronas lanzadas con `unawaited`
    /// (`_scheduleEverything` y `_onSettingsChanged`).
    Future<void> settle() async {
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }

    Task pastTask(String id, DateTime day, DateTime now) => Task(
          id: id,
          title: 'Tarea $id',
          scheduledDate: day,
          scheduledTime: now.subtract(const Duration(minutes: 5)),
          createdAt: now,
        );

    test('una tarea con horario pasado NO impide programar el cierre de jornada',
        () async {
      final now = DateTime.now();

      // Tarea HOY con horario ~now−5 min (pasada): pre-fix, su
      // `zonedSchedule` con fecha pasada lanzaba ArgumentError y abortaba la
      // cadena completa del controlador (tareas → resúmenes → cierre).
      await tasksBox.add(
        pastTask('past-today',
            DateTime(now.year, now.month, now.day), now),
      );
      // Tarea AYER (también pasada): garantiza que la jornada reportada por el
      // cierre tenga tareas y `syncDayClosure` programe 0x60000003
      // independientemente de si el test corre antes o después de la hora de
      // reset de día (04:00 local).
      await tasksBox.add(
        pastTask('past-yesterday',
            DateTime(now.year, now.month, now.day)
                .subtract(const Duration(days: 1)),
            now),
      );

      // El cierre arranca OFF (default): al construir el controlador se hace la
      // primera pasada (tasks → resúmenes → cierre) con la tarea pasada presente.
      container.read(dailyReminderControllerProvider);
      await settle();

      // Con el toggle OFF el cierre queda cancelado (idempotente).
      expect(scheduler.cancelled, contains(dayClosureReminderId));

      // Regresión del Verifier: activar el cierre re-dispara TODO. La tarea
      // pasada debe CANCELARSE (no lanzar) y la sección del cierre debe
      // ejecutarse SÍ o SÍ, dejando 0x60000003 programado para el próximo reset.
      await container
          .read(settingsProvider.notifier)
          .updateEnableDayClosure(true);
      await settle();

      expect(
        scheduler.scheduled.containsKey(dayClosureReminderId),
        isTrue,
        reason: 'una tarea con hora pasada no debe abortar el cierre de jornada',
      );
    });
  });

  group('DailyReminderController - alerta de racha en peligro (F2)', () {
    late Directory tempDir;
    late SettingsBox settingsBox;
    late TasksBox tasksBox;
    late StreaksBox streaksBox;
    late BadgesBox badgesBox;
    late PlayerProgressBox playerProgressBox;
    late ControllerFakeScheduler scheduler;
    late ProviderContainer container;

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('slate_controller_alerta');
      Hive.init(tempDir.path);
      _registerHiveAdapters();
    });

    setUp(() async {
      settingsBox = SettingsBox();
      await settingsBox.init();
      tasksBox = TasksBox();
      await tasksBox.init();
      streaksBox = StreaksBox();
      await streaksBox.init();
      badgesBox = BadgesBox();
      await badgesBox.init();
      playerProgressBox = PlayerProgressBox();
      await playerProgressBox.init();

      scheduler = ControllerFakeScheduler();
      container = ProviderContainer(
        overrides: [
          settingsBoxProvider.overrideWithValue(settingsBox),
          tasksBoxProvider.overrideWithValue(tasksBox),
          streaksBoxProvider.overrideWithValue(streaksBox),
          badgesBoxProvider.overrideWithValue(badgesBox),
          playerProgressBoxProvider.overrideWithValue(playerProgressBox),
          reminderManagerProvider.overrideWithValue(
            ReminderManager(scheduler: scheduler),
          ),
        ],
      );
      addTearDown(container.dispose);
    });

    tearDown(() async {
      await Hive.close();
      await Hive.deleteBoxFromDisk('settings');
      await Hive.deleteBoxFromDisk('tasks');
      await Hive.deleteBoxFromDisk('streaks');
      await Hive.deleteBoxFromDisk('badges');
      await Hive.deleteBoxFromDisk('player_progress');
    });

    tearDownAll(() async {
      await tempDir.delete(recursive: true);
    });

    Future<void> settle() async {
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }

    DateTime today() =>
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    /// Siembra una racha activa de [streakDays] y una tarea pendiente HOY.
    Future<void> seedActiveStreak(int streakDays) async {
      await streaksBox.updateStreak(Streak(
        id: 'main_streak',
        currentStreak: streakDays,
        longestStreak: streakDays,
        updatedAt: DateTime.now(),
      ));
      await tasksBox.add(Task(
        id: 't1',
        title: 'Misión de hoy',
        scheduledDate: today(),
        createdAt: DateTime.now(),
      ));
    }

    test('con racha < 3 la alerta NUNCA se programa (aunque no haya '
        'completados hoy)', () async {
      await seedActiveStreak(2);
      container.read(dailyReminderControllerProvider);
      await settle();

      expect(
        scheduler.scheduled.containsKey(streakAtRiskReminderId),
        isFalse,
        reason: 'racha < 3 → la alerta 0x60000004 se cancela',
      );
      expect(scheduler.cancelled, contains(streakAtRiskReminderId));
    });

    test('al completar la primera tarea del día la alerta se CANCELA', () async {
      await seedActiveStreak(3);
      container.read(dailyReminderControllerProvider);
      await settle();

      // Completar la única tarea del día activa la cancelación vía el cambio
      // de tasksProvider (la condición "sin completados hoy" deja de cumplirse).
      await container.read(tasksProvider.notifier).toggleComplete('t1');
      await settle();

      expect(
        scheduler.scheduled.containsKey(streakAtRiskReminderId),
        isFalse,
        reason: 'tras la primera completación del día la alerta queda cancelada',
      );
      expect(scheduler.cancelled, contains(streakAtRiskReminderId));
    });
  });
}