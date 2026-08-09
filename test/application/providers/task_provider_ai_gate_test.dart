import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:slate_app/application/providers/notification_providers.dart';
import 'package:slate_app/application/providers/settings_provider.dart';
import 'package:slate_app/application/providers/task_provider.dart';
import 'package:slate_app/application/services/ai_service.dart';
import 'package:slate_app/application/services/reminder_manager.dart';
import 'package:slate_app/application/services/reminder_scheduler.dart';
import 'package:slate_app/application/services/thematic_texts_catalog.dart';
import 'package:slate_app/data/hive/adapters/task_adapter.dart';
import 'package:slate_app/data/hive/adapters/user_settings_adapter.dart';
import 'package:slate_app/data/hive/boxes/settings_box.dart';
import 'package:slate_app/data/hive/boxes/tasks_box.dart';
import 'package:slate_app/data/hive/boxes/thematic_text_cache_box.dart';
import 'package:slate_app/domain/entities/user_settings.dart';

/// Espía del servicio de IA: "tiene" API key y cuenta cada llamada a Gemini,
/// devolviendo un resultado controlado. Permite verificar que la IA se invoca
/// SOLO cuando el opt-in "Textos con IA" está activo.
class SpyAIService extends AIService {
  int generateCalls = 0;

  @override
  bool get canUseAI => true;

  @override
  Future<ThematicTextAIResult?> generateThematicText({
    required String eventType,
    required String titleContext,
  }) async {
    generateCalls++;
    return ThematicTextAIResult(
      title: 'IA $eventType',
      body: 'Cuerpo $eventType',
    );
  }
}

/// Fake del contrato de bajo nivel (evita el plugin nativo en `flutter test`).
class FakeScheduler implements ReminderScheduler {
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
  late SettingsBox settingsBox;
  late ThematicTextCache cache;
  late SpyAIService spy;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('slate_ai_gate_test');
    Hive.init(tempDir.path);
    Hive.registerAdapter(TaskAdapter());
    Hive.registerAdapter(UserSettingsAdapter());
  });

  setUp(() async {
    tasksBox = TasksBox();
    await tasksBox.init();
    settingsBox = SettingsBox();
    await settingsBox.init();
    cache = ThematicTextCache();
    await cache.init();
    spy = SpyAIService();
  });

  tearDown(() async {
    await Hive.close();
    await Hive.deleteBoxFromDisk('tasks');
    await Hive.deleteBoxFromDisk('settings');
    await Hive.deleteBoxFromDisk('thematic_texts_cache');
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  ProviderContainer createContainer() => ProviderContainer(
        overrides: [
          tasksBoxProvider.overrideWithValue(tasksBox),
          settingsBoxProvider.overrideWithValue(settingsBox),
          aiServiceProvider.overrideWithValue(spy),
          thematicTextCacheProvider.overrideWithValue(cache),
          reminderManagerProvider.overrideWithValue(
            ReminderManager(scheduler: FakeScheduler()),
          ),
        ],
      );

  /// Guarda una tarea sin horario (sin recordatorio) y espera a que terminen
  /// las tareas en segundo plano (incluida la generación IA, que es
  /// `unawaited`). Se usa una espera real del event loop porque la generación
  /// espera escrituras a Hive (I/O asíncrona del sistema de archivos), que
  /// `pumpEventQueue()` no llega a drenar por completo.
  Future<void> createAndSettleTask(ProviderContainer container) async {
    await container.read(tasksProvider.notifier).addTask(
          title: 'Misión de prueba',
          scheduledDate: DateTime(2026, 1, 20),
        );
    for (var i = 0; i < 30; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  group('Gating del opt-in de IA en el guardado (Hallazgo 1)', () {
    test('toggle OFF + tema ON + API key: la IA NUNCA se invoca', () async {
      await settingsBox
          .updateSettings(const UserSettings(slateSystemTheme: true));
      expect(settingsBox.getSettings().useAIThematicTexts, isFalse);

      final container = createContainer();
      addTearDown(container.dispose);

      await createAndSettleTask(container);

      // Regresión del Hallazgo 1: antes, con tema ON + API key + toggle OFF,
      // la app llamaba a Gemini en el path de programación. Hoy la generación
      // SOLO ocurre al guardar y está gateada por ambos flags.
      expect(spy.generateCalls, 0,
          reason: 'con useAIThematicTexts=false la IA no debe invocarse');
      // Y no queda nada en la caché temática (no hay escritura sin generación).
      expect(cache.get('summary|morning'), isNull);
      expect(cache.get('summary|evening'), isNull);
      expect(cache.get('summary|closure'), isNull);
    });

    test('tema OFF + toggle ON: la IA tampoco se invoca', () async {
      await settingsBox
          .updateSettings(const UserSettings(useAIThematicTexts: true));
      expect(settingsBox.getSettings().slateSystemTheme, isFalse);

      final container = createContainer();
      addTearDown(container.dispose);

      await createAndSettleTask(container);

      expect(spy.generateCalls, 0,
          reason: 'sin tema Slate System no hay textos temáticos generados');
    });

    test('toggle ON + tema ON: al guardar se genera la tarea y las 3 variantes '
        'globales y quedan en caché', () async {
      await settingsBox.updateSettings(
        const UserSettings(
          slateSystemTheme: true,
          useAIThematicTexts: true,
        ),
      );

      final container = createContainer();
      addTearDown(container.dispose);

      await createAndSettleTask(container);

      // 1 variante de la tarea + 3 globales (mañana/tarde/cierre).
      expect(spy.generateCalls, greaterThan(0));
      expect(spy.generateCalls, 4);

      final task = container.read(tasksProvider).single;
      expect(
        cache.get(ThematicTextsCatalog.taskCacheKey(task)),
        isNotNull,
        reason: 'la variante de la tarea queda en caché local',
      );
      expect(cache.get('summary|morning'), isNotNull);
      expect(cache.get('summary|evening'), isNotNull);
      expect(cache.get('summary|closure'), isNotNull);
    });
  });
}