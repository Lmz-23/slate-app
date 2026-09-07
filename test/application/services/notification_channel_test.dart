import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:slate_app/application/providers/notification_providers.dart';
import 'package:slate_app/application/providers/player_provider.dart';
import 'package:slate_app/application/providers/settings_provider.dart';
import 'package:slate_app/application/providers/streak_provider.dart';
import 'package:slate_app/application/providers/task_provider.dart';
import 'package:slate_app/application/services/notification_service.dart';
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
import 'package:slate_app/domain/entities/user_settings.dart';

/// Fake del contrato de bajo nivel: programación instantánea y sin plugin.
/// Permite que la cadena asíncrona del controlador (`_scheduleEverything`)
/// drene de forma determinista antes de que el test termine.
class ChannelFakeScheduler implements ReminderScheduler {
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

/// Verifica que el canal `task_reminders` se deriva y recrea con los toggles de
/// sonido/vibración/badge (Mejora 2).
///
/// En Android 8+ los toggles se aplican al CREAR el canal: al cambiar un ajuste
/// el controlador debe llamar a `updateChannelForSettings` para recrearlo y que
/// la nueva configuración aplique a los próximos recordatorios.
void main() {
  group('NotificationService.updateChannelForSettings', () {
    test('actualiza la configuración efectiva del canal con los nuevos toggles',
        () async {
      final service = NotificationService.instance;

      // Estado por defecto: sonido, vibración y badge activos.
      await service.updateChannelForSettings(const UserSettings());
      expect(service.channelSettings.playSound, isTrue);
      expect(service.channelSettings.enableVibration, isTrue);
      expect(service.channelSettings.showBadge, isTrue);

      // El usuario desactiva el sonido -> canal silencioso; vibración intacta.
      await service.updateChannelForSettings(
          const UserSettings(notificationSound: false));
      expect(service.channelSettings.playSound, isFalse);
      expect(service.channelSettings.enableVibration, isTrue);

      // Desactiva la vibración -> en Android también se silencia el canal.
      await service.updateChannelForSettings(const UserSettings(
          notificationSound: true, notificationVibration: false));
      expect(service.channelSettings.enableVibration, isFalse);
      expect(service.channelSettings.playSound, isFalse,
          reason: 'sin vibración Android no reproduce sonido');

      // Desactiva el badge -> showBadge false.
      await service.updateChannelForSettings(const UserSettings(
          notificationSound: true, notificationVibration: true,
          notificationBadge: false));
      expect(service.channelSettings.showBadge, isFalse);
      expect(service.channelSettings.playSound, isTrue);
    });
  });

  group('DailyReminderController recrea el canal al cambiar un toggle', () {
    late Directory tempDir;
    late SettingsBox settingsBox;
    late TasksBox tasksBox;
    late StreaksBox streaksBox;
    late BadgesBox badgesBox;
    late PlayerProgressBox playerProgressBox;
    late ChannelFakeScheduler scheduler;
    late ProviderContainer container;

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('slate_channel_test');
      Hive.init(tempDir.path);
      Hive.registerAdapter(TaskAdapter());
      Hive.registerAdapter(UserSettingsAdapter());
      Hive.registerAdapter(StreakAdapter());
      Hive.registerAdapter(BadgeAdapter());
      Hive.registerAdapter(PlayerProfileAdapter());
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

      scheduler = ChannelFakeScheduler();
      container = ProviderContainer(
        overrides: [
          settingsBoxProvider.overrideWithValue(settingsBox),
          tasksBoxProvider.overrideWithValue(tasksBox),
          streaksBoxProvider.overrideWithValue(streaksBox),
          badgesBoxProvider.overrideWithValue(badgesBox),
          playerProgressBoxProvider.overrideWithValue(playerProgressBox),
          // El canal se recrea a través de `NotificationService`; la
          // programación de recordatorios usa el fake para que la cadena
          // asíncrona del controlador drene sin depender del plugin.
          reminderManagerProvider.overrideWithValue(
            ReminderManager(scheduler: scheduler),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Partir de un estado limpio del servicio singleton (los tests comparten
      // `NotificationService.instance`).
      await NotificationService.instance
          .updateChannelForSettings(const UserSettings());
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

    /// Espera a que drenen las cadenas asíncronas lanzadas con `unawaited`.
    Future<void> settle() async {
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }

    test('cambiar notificationSound en Ajustes recrea el canal al instante',
        () async {
      final service = NotificationService.instance;
      // El controlador queda "vivo" escuchando los ajustes como en SlateApp.
      container.read(dailyReminderControllerProvider);

      await container
          .read(settingsProvider.notifier)
          .updateNotificationSound(false);
      await settle();

      expect(service.channelSettings.playSound, isFalse);
    });

    test('cambiar notificationVibration recrea el canal y silencia el sonido',
        () async {
      final service = NotificationService.instance;
      container.read(dailyReminderControllerProvider);

      await container
          .read(settingsProvider.notifier)
          .updateNotificationVibration(false);
      await settle();

      expect(service.channelSettings.enableVibration, isFalse);
      expect(service.channelSettings.playSound, isFalse);
    });

    test('cambiar notificationBadge recrea el canal (sin tocar sonido)',
        () async {
      final service = NotificationService.instance;
      container.read(dailyReminderControllerProvider);

      await container
          .read(settingsProvider.notifier)
          .updateNotificationBadge(false);
      await settle();

      expect(service.channelSettings.showBadge, isFalse);
      expect(service.channelSettings.playSound, isTrue);
    });
  });
}