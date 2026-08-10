import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:slate_app/application/providers/backup_provider.dart';
import 'package:slate_app/application/providers/category_provider.dart';
import 'package:slate_app/application/providers/notification_providers.dart';
import 'package:slate_app/application/providers/settings_provider.dart';
import 'package:slate_app/application/providers/streak_provider.dart';
import 'package:slate_app/application/providers/task_provider.dart';
import 'package:slate_app/data/backup/backup_codec.dart';
import 'package:slate_app/data/backup/backup_file_store.dart';
import 'package:slate_app/data/backup/backup_service.dart';
import 'package:slate_app/data/hive/adapters/badge_adapter.dart';
import 'package:slate_app/data/hive/adapters/category_adapter.dart';
import 'package:slate_app/data/hive/adapters/streak_adapter.dart';
import 'package:slate_app/data/hive/adapters/task_adapter.dart';
import 'package:slate_app/data/hive/adapters/user_settings_adapter.dart';
import 'package:slate_app/data/hive/boxes/badges_box.dart';
import 'package:slate_app/data/hive/boxes/categories_box.dart';
import 'package:slate_app/data/hive/boxes/settings_box.dart';
import 'package:slate_app/data/hive/boxes/streaks_box.dart';
import 'package:slate_app/data/hive/boxes/tasks_box.dart';
import 'package:slate_app/data/hive/boxes/thematic_text_cache_box.dart';
import 'package:slate_app/domain/entities/badge.dart';
import 'package:slate_app/domain/entities/category.dart';
import 'package:slate_app/domain/entities/streak.dart';
import 'package:slate_app/domain/entities/task.dart';
import 'package:slate_app/domain/entities/user_settings.dart';
import 'package:slate_app/domain/enums/app_theme_mode.dart';
import 'package:slate_app/domain/enums/badge_type.dart';
import 'package:slate_app/domain/enums/task_priority.dart';

void main() {
  late Directory tempDir;
  late TasksBox tasksBox;
  late CategoriesBox categoriesBox;
  late StreaksBox streaksBox;
  late BadgesBox badgesBox;
  late SettingsBox settingsBox;
  late ThematicTextCache cache;
  late Box<dynamic> metaBox;
  late BackupService service;

  const taskIds = ['b', 'a'];

  Task task(String id) => Task(
        id: id,
        title: 'Tarea $id',
        scheduledDate: DateTime(2026, 8, 9),
        scheduledTime: id == 'a' ? DateTime(2026, 8, 9, 8) : null,
        priority: id == 'a' ? TaskPriority.high : TaskPriority.normal,
        categoryId: 'c-1',
        createdAt: DateTime(2026, 8, 1),
        isCompleted: id == 'b',
        completedAt: id == 'b' ? DateTime(2026, 8, 9, 9) : null,
      );

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('slate_backup_test');
    Hive.init(tempDir.path);
    Hive.registerAdapter(TaskAdapter());
    Hive.registerAdapter(CategoryAdapter());
    Hive.registerAdapter(BadgeAdapter());
    Hive.registerAdapter(StreakAdapter());
    Hive.registerAdapter(UserSettingsAdapter());
  });

  setUp(() async {
    tasksBox = TasksBox();
    await tasksBox.init();
    categoriesBox = CategoriesBox();
    await categoriesBox.init();
    streaksBox = StreaksBox();
    await streaksBox.init();
    badgesBox = BadgesBox();
    await badgesBox.init();
    settingsBox = SettingsBox();
    await settingsBox.init();
    cache = ThematicTextCache();
    await cache.init();
    metaBox = await Hive.openBox<dynamic>('app_meta');

    service = BackupService(
      tasksBox: tasksBox,
      categoriesBox: categoriesBox,
      streaksBox: streaksBox,
      badgesBox: badgesBox,
      settingsBox: settingsBox,
      thematicCache: cache,
      appMetaBox: metaBox,
      fileStore: BackupFileStore(baseDirectory: tempDir),
    );
  });

  tearDown(() async {
    await Hive.close();
    await Hive.deleteBoxFromDisk('tasks');
    await Hive.deleteBoxFromDisk('categories');
    await Hive.deleteBoxFromDisk('streaks');
    await Hive.deleteBoxFromDisk('badges');
    await Hive.deleteBoxFromDisk('settings');
    await Hive.deleteBoxFromDisk('app_meta');
    await Hive.deleteBoxFromDisk('thematic_texts_cache');
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  Future<void> seedBoxes() async {
    for (final id in taskIds) {
      await tasksBox.add(task(id));
    }
    await categoriesBox.add(
        Category(id: 'c-1', name: 'Hogar', colorHex: '#FF5252', createdAt: DateTime(2026, 8, 1)));
    await streaksBox.updateStreak(Streak(
      id: 'main_streak',
      currentStreak: 4,
      longestStreak: 7,
      lastCompletedDate: DateTime.utc(2026, 8, 8),
      updatedAt: DateTime(2026, 8, 9, 10),
    ));
    await badgesBox.add(Badge(
      id: 'b-1',
      type: BadgeType.streak7,
      name: 'Semana Perfecta',
      iconName: 'fire',
      unlockedAt: DateTime(2026, 8, 7),
      isDisplayed: true,
    ));
    await settingsBox.updateSettings(const UserSettings(
      userName: 'Ada',
      dayResetHour: 6,
      notificationsEnabled: false,
      themeMode: AppThemeMode.light,
      timezone: 'Europe/Madrid',
      notificationLeadTimeMinutes: 20,
      useAIThematicTexts: true,
      enableDayClosure: true,
    ));
    await metaBox.put('notification_prompted', true);
    await metaBox.put('ai_thematic_notice_shown', true);
    await cache.put(
      'task_b',
      ThematicTextCacheEntry(
        title: 'Título temático',
        body: 'Cuerpo temático',
        createdAt: DateTime.utc(2026, 8, 1),
      ),
    );
  }

  Future<void> clearAllBoxes() async {
    await tasksBox.box.clear();
    await categoriesBox.box.clear();
    await streaksBox.box.clear();
    await badgesBox.box.clear();
    await settingsBox.box.clear();
    await metaBox.clear();
    await cache.clear();
  }

  group('BackupService.exportData', () {
    test('lee las cajas actuales y genera un archivo JSON válido con schemaVersion 1',
        () async {
      await seedBoxes();

      final result = await service.exportData(now: DateTime(2026, 8, 9, 12));

      expect(result.filePath, isNotNull);
      expect(result.taskCount, 2);
      expect(result.categoryCount, 1);
      expect(result.badgeCount, 1);

      final file = File(result.filePath!);
      expect(await file.exists(), isTrue);
      expect(file.path, contains('slate_backup_'));
      expect(file.path, contains('20260809_120000'));

      final decoded = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      expect(decoded['app'], 'slate');
      expect(decoded['schemaVersion'], 1);

      final data = decoded['data'] as Map<String, dynamic>;
      expect((data['tasks'] as List), hasLength(2));
      expect((data['categories'] as List), hasLength(1));
      expect((data['streaks'] as List), hasLength(1));
      expect((data['badges'] as List), hasLength(1));
      expect((data['appMeta'] as Map)['notification_prompted'], isTrue);
      expect((data['thematicTextCache'] as Map).containsKey('task_b'), isTrue);
    });
  });

  group('BackupService.importFromPath', () {
    test('restaura el estado completo en cajas vacías (roundtrip export→import)',
        () async {
      await seedBoxes();
      final exported = await service.exportData(now: DateTime(2026, 8, 9, 12));
      await clearAllBoxes();

      final result = await service.importFromPath(exported.filePath!);

      expect(result.taskCount, 2);
      expect(result.taskCount, tasksBox.getAll().length);

      // Tareas restauradas con sus settings.
      final restoredTasks = tasksBox.getAll().toSet();
      expect(restoredTasks, taskIds.map(task).toSet());
      expect(tasksBox.get('b')!.isCompleted, isTrue);
      expect(tasksBox.get('b')!.completedAt, isNotNull);

      // Categorías, rachas, insignias.
      expect(categoriesBox.getAll().single.name, 'Hogar');
      expect(streaksBox.getStreak().currentStreak, 4);
      expect(streaksBox.getStreak().longestStreak, 7);
      expect(badgesBox.getAll().single.type, BadgeType.streak7);

      // Ajustes.
      final settings = settingsBox.getSettings();
      expect(settings.userName, 'Ada');
      expect(settings.useAIThematicTexts, isTrue);
      expect(settings.enableDayClosure, isTrue);
      expect(settings.notificationLeadTimeMinutes, 20);

      // Flags y caché temática.
      expect(metaBox.get('notification_prompted'), isTrue);
      expect(metaBox.get('ai_thematic_notice_shown'), isTrue);
      expect(cache.get('task_b'), isNotNull);
      expect(cache.get('task_b')!.title, 'Título temático');
    });

    test('sobrescribe los datos existentes al importar', () async {
      await seedBoxes();
      final exported = await service.exportData(now: DateTime(2026, 8, 9, 12));

      // Cambiamos el estado actual ANTES de importar: debe quedar reemplazado.
      await tasksBox.add(task('dato-nuevo'));
      await settingsBox.updateSettings(const UserSettings(userName: 'Nuevo'));
      expect(tasksBox.getAll(), hasLength(3));

      await service.importFromPath(exported.filePath!);

      expect(tasksBox.getAll(), hasLength(2));
      expect(tasksBox.get('dato-nuevo'), isNull);
      expect(settingsBox.getSettings().userName, 'Ada');
    });

    test('rechaza un archivo inválido sin tocar los datos actuales', () async {
      await seedBoxes();
      final invalidFile = File('${tempDir.path}/invalid.json');
      await invalidFile.writeAsString('{"app": "slate", "schemaVersion": 99}');

      await expectLater(
        service.importFromPath(invalidFile.path),
        throwsA(isA<BackupException>()),
      );

      // Nada cambió.
      expect(tasksBox.getAll(), hasLength(2));
      expect(categoriesBox.getAll().single.name, 'Hogar');
      expect(settingsBox.getSettings().userName, 'Ada');
      expect(metaBox.get('notification_prompted'), isTrue);
    });

    test('rechaza un archivo que no es JSON sin tocar los datos', () async {
      await seedBoxes();
      final badFile = File('${tempDir.path}/rotto.json');
      await badFile.writeAsString('esto no es json');

      await expectLater(
        service.importFromPath(badFile.path),
        throwsA(isA<BackupException>()),
      );

      expect(tasksBox.getAll(), hasLength(2));
    });
  });

  group('BackupController (integración con providers)', () {
    ProviderContainer makeContainer() {
      return ProviderContainer(overrides: [
        tasksBoxProvider.overrideWithValue(tasksBox),
        categoriesBoxProvider.overrideWithValue(categoriesBox),
        streaksBoxProvider.overrideWithValue(streaksBox),
        badgesBoxProvider.overrideWithValue(badgesBox),
        settingsBoxProvider.overrideWithValue(settingsBox),
        thematicTextCacheProvider.overrideWithValue(cache),
        appMetaBoxProvider.overrideWithValue(metaBox),
        backupFileStoreProvider
            .overrideWithValue(BackupFileStore(baseDirectory: tempDir)),
      ]);
    }

    test('tras importar, los providers leen el estado restaurado', () async {
      await seedBoxes();
      final exported = await service.exportData(now: DateTime(2026, 8, 9, 12));
      await clearAllBoxes();

      final container = makeContainer();
      addTearDown(container.dispose);

      final controller = container.read(backupControllerProvider.notifier);
      final result = await controller.importData(exported.filePath!);

      expect(result, isNotNull);
      expect(container.read(backupControllerProvider).message, contains('Datos restaurados'));

      // Los providers vivos reflejan el estado restaurado.
      final tasks = container.read(tasksProvider);
      expect(tasks, hasLength(2));
      expect(tasks.map((t) => t.id), containsAll(taskIds));

      final categories = container.read(categoriesProvider);
      expect(categories.single.name, 'Hogar');

      expect(container.read(streakProvider).currentStreak, 4);
      expect(container.read(badgesProvider).single.type, BadgeType.streak7);
      expect(container.read(settingsProvider).userName, 'Ada');
    });

    test('exportData publica la ruta y el resumen en el estado', () async {
      await seedBoxes();
      final container = makeContainer();
      addTearDown(container.dispose);

      final controller = container.read(backupControllerProvider.notifier);
      final result = await controller.exportData();

      expect(result, isNotNull);
      expect(result!.filePath, isNotNull);
      expect(container.read(backupControllerProvider).filePath, result.filePath);
      expect(container.read(backupControllerProvider).message, contains('tareas'));
      expect(container.read(backupControllerProvider).busy, isFalse);
    });
  });
}