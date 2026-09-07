import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:slate_app/data/backup/backup_file_store.dart';
import 'package:slate_app/data/backup/backup_service.dart';
import 'package:slate_app/data/hive/adapters/badge_adapter.dart';
import 'package:slate_app/data/hive/adapters/category_adapter.dart';
import 'package:slate_app/data/hive/adapters/companion_state_adapter.dart';
import 'package:slate_app/data/hive/adapters/player_profile_adapter.dart';
import 'package:slate_app/data/hive/adapters/streak_adapter.dart';
import 'package:slate_app/data/hive/adapters/task_adapter.dart';
import 'package:slate_app/data/hive/adapters/user_settings_adapter.dart';
import 'package:slate_app/data/hive/boxes/badges_box.dart';
import 'package:slate_app/data/hive/boxes/categories_box.dart';
import 'package:slate_app/data/hive/boxes/companion_state_box.dart';
import 'package:slate_app/data/hive/boxes/player_progress_box.dart';
import 'package:slate_app/data/hive/boxes/settings_box.dart';
import 'package:slate_app/data/hive/boxes/streaks_box.dart';
import 'package:slate_app/data/hive/boxes/tasks_box.dart';
import 'package:slate_app/domain/entities/companion_state.dart';
import 'package:slate_app/domain/entities/player_profile.dart';

void main() {
  late Directory tempDir;
  late TasksBox tasksBox;
  late CategoriesBox categoriesBox;
  late StreaksBox streaksBox;
  late BadgesBox badgesBox;
  late SettingsBox settingsBox;
  late PlayerProgressBox playerBox;
  late CompanionStateBox companionBox;
  late Box<dynamic> metaBox;
  late BackupService service;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('slate_backup_f4_test');
    Hive.init(tempDir.path);
    Hive.registerAdapter(TaskAdapter());
    Hive.registerAdapter(CategoryAdapter());
    Hive.registerAdapter(BadgeAdapter());
    Hive.registerAdapter(StreakAdapter());
    Hive.registerAdapter(UserSettingsAdapter());
    Hive.registerAdapter(PlayerProfileAdapter());
    Hive.registerAdapter(CompanionStateAdapter());
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
    playerBox = PlayerProgressBox();
    await playerBox.init();
    companionBox = CompanionStateBox();
    await companionBox.init();
    metaBox = await Hive.openBox<dynamic>('app_meta');

    service = BackupService(
      tasksBox: tasksBox,
      categoriesBox: categoriesBox,
      streaksBox: streaksBox,
      badgesBox: badgesBox,
      settingsBox: settingsBox,
      appMetaBox: metaBox,
      playerProgressBox: playerBox,
      companionStateBox: companionBox,
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
    await Hive.deleteBoxFromDisk('player_progress');
    await Hive.deleteBoxFromDisk('companion_state');
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  Future<void> seedPlayerAndCompanion() async {
    await playerBox.updateProfile(PlayerProfile(
      id: 'main_player',
      totalXp: 327,
      level: 3,
      shownLevelUps: const {2, 3},
      updatedAt: DateTime(2026, 8, 10, 11, 30),
    ));
    await companionBox.updateState(CompanionState(
      id: 'main_companion',
      questClaimedOn: '2026-8-10',
      questVisibleOn: '2026-8-10',
      questVisibleDecision: true,
      updatedAt: DateTime(2026, 8, 10, 11, 30),
    ));
  }

  group('BackupService F4 - exportación del progreso', () {
    test('al exportar, el JSON incluye player_progress y companion_state', () async {
      await seedPlayerAndCompanion();

      final result = await service.exportData(now: DateTime(2026, 8, 10, 12));
      final decoded =
          jsonDecode(await File(result.filePath!).readAsString())
              as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>;

      final player = data['playerProgress'] as Map<String, dynamic>;
      expect(player['totalXp'], 327);
      expect(player['level'], 3);
      expect(player['shownLevelUps'], [2, 3]);

      final companion = data['companionState'] as Map<String, dynamic>;
      expect(companion['questClaimedOn'], '2026-8-10');
      expect(companion['questVisibleDecision'], isTrue);
    });
  });

  group('BackupService F4 - importación (roundtrip)', () {
    test('export→import restaura XP/nivel y quest en cajas vacías', () async {
      await seedPlayerAndCompanion();
      final exported = await service.exportData(now: DateTime(2026, 8, 10, 12));

      // Vaciar TODO (incluidas las cajas nuevas).
      await playerBox.box.clear();
      await companionBox.box.clear();
      expect(playerBox.getProfile().totalXp, 0);
      expect(companionBox.getState().questClaimedOn, isNull);

      final result = await service.importFromPath(exported.filePath!);
      expect(result, isNotNull);

      final restoredPlayer = playerBox.getProfile();
      expect(restoredPlayer.totalXp, 327);
      expect(restoredPlayer.level, 3);
      expect(restoredPlayer.shownLevelUps, {2, 3});

      final restoredCompanion = companionBox.getState();
      expect(restoredCompanion.questClaimedOn, '2026-8-10');
      expect(restoredCompanion.questVisibleOn, '2026-8-10');
      expect(restoredCompanion.questVisibleDecision, isTrue);
    });

    test('el import SOBRESCRIBE los valores actuales de player/companion',
        () async {
      await seedPlayerAndCompanion();
      final exported = await service.exportData(now: DateTime(2026, 8, 10, 12));

      // Cambiamos el estado actual ANTES de importar.
      await playerBox.updateProfile(PlayerProfile(
        id: 'main_player',
        totalXp: 999,
        level: 5,
        shownLevelUps: const {2, 3, 4, 5},
        updatedAt: DateTime(2026, 9, 1),
      ));
      await companionBox.updateState(CompanionState(
        id: 'main_companion',
        questClaimedOn: null,
        questVisibleOn: null,
        questVisibleDecision: false,
        updatedAt: DateTime(2026, 9, 1),
      ));

      await service.importFromPath(exported.filePath!);

      expect(playerBox.getProfile().totalXp, 327,
          reason: 'el backup manda (import = overwrite)');
      expect(companionBox.getState().questClaimedOn, '2026-8-10');
    });

    test('un backup SIN las secciones F4 NO toca las cajas actuales', () async {
      await seedPlayerAndCompanion();

      // Exporta con un servicio SIN las cajas F4: el JSON no lleva las
      // secciones (equivalente a un backup hecho antes de F4).
      final legacyService = BackupService(
        tasksBox: tasksBox,
        categoriesBox: categoriesBox,
        streaksBox: streaksBox,
        badgesBox: badgesBox,
        settingsBox: settingsBox,
        appMetaBox: metaBox,
        fileStore: BackupFileStore(baseDirectory: tempDir),
      );
      final legacyExport =
          await legacyService.exportData(now: DateTime(2026, 8, 10, 12));
      final raw = await File(legacyExport.filePath!).readAsString();
      expect(raw.contains('playerProgress'), isFalse);
      expect(raw.contains('companionState'), isFalse);

      await service.importFromPath(legacyExport.filePath!);

      // El progreso actual se conserva (no se machaca con un backfill).
      expect(playerBox.getProfile().totalXp, 327);
      expect(companionBox.getState().questClaimedOn, '2026-8-10');
    });
  });
}