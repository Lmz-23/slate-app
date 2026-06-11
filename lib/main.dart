import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';
import 'data/hive/adapters/task_adapter.dart';
import 'data/hive/adapters/category_adapter.dart';
import 'data/hive/adapters/badge_adapter.dart';
import 'data/hive/adapters/streak_adapter.dart';
import 'data/hive/adapters/user_settings_adapter.dart';
import 'data/hive/boxes/tasks_box.dart';
import 'data/hive/boxes/categories_box.dart';
import 'data/hive/boxes/badges_box.dart';
import 'data/hive/boxes/streaks_box.dart';
import 'data/hive/boxes/settings_box.dart';
import 'application/providers/task_provider.dart';
import 'application/providers/category_provider.dart';
import 'application/providers/streak_provider.dart';
import 'application/providers/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  Hive.registerAdapter(TaskAdapter());
  Hive.registerAdapter(CategoryAdapter());
  Hive.registerAdapter(BadgeAdapter());
  Hive.registerAdapter(StreakAdapter());
  Hive.registerAdapter(UserSettingsAdapter());

  final tasksBox = TasksBox();
  await tasksBox.init();

  final categoriesBox = CategoriesBox();
  await categoriesBox.init();

  final badgesBox = BadgesBox();
  await badgesBox.init();

  final streaksBox = StreaksBox();
  await streaksBox.init();

  final settingsBox = SettingsBox();
  await settingsBox.init();

  runApp(
    ProviderScope(
      overrides: [
        tasksBoxProvider.overrideWithValue(tasksBox),
        categoriesBoxProvider.overrideWithValue(categoriesBox),
        badgesBoxProvider.overrideWithValue(badgesBox),
        streaksBoxProvider.overrideWithValue(streaksBox),
        settingsBoxProvider.overrideWithValue(settingsBox),
      ],
      child: const SlateApp(),
    ),
  );
}