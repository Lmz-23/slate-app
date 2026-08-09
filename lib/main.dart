import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/data/latest.dart' as tz_data;
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
import 'data/hive/boxes/thematic_text_cache_box.dart';
import 'application/providers/task_provider.dart';
import 'application/providers/category_provider.dart';
import 'application/providers/streak_provider.dart';
import 'application/providers/settings_provider.dart';
import 'application/providers/notification_providers.dart';
import 'application/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa la base de datos de zonas horarias (idempotente).
  // Necesaria para TimezoneService.nowInTimezone antes del primer frame.
  tz_data.initializeTimeZones();

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

  // Caché local de variantes temáticas (Slate System) generadas con IA. Se
  // abre antes de runApp para que el resolver pueda leerla al programar.
  final thematicTextCache = ThematicTextCache();
  await thematicTextCache.init();

  // ─────────────────────────────────────────────────────────────────────────
  // Sistema de notificaciones (P1/P2/P3/P5)
  // ─────────────────────────────────────────────────────────────────────────
  // Inicializa el plugin y fija la zona horaria CONFIGURADA por el usuario en
  // `tz.local`; sin esto, `zonedSchedule` interpretaría los instantes en UTC
  // y los recordatorios se dispararían a otra hora.
  final notifications = NotificationService.instance;
  final settings = settingsBox.getSettings();
  // Los ajustes se pasan a `init` para crear el canal `task_reminders` ya con
  // los toggles de sonido/vibración/badge del usuario (Mejora 2).
  await notifications.init(timezone: settings.timezone, settings: settings);

  // P1: solicitar el permiso POST_NOTIFICATIONS en el primer arranque (solo
  // una vez por instalación). Si el usuario lo deniega no se bloquea el flujo:
  // el toggle de Ajustes queda disponible y volverá a solicitarlo si se
  // activa. La bandera se guarda en una caja auxiliar sin tocar el adapter de
  // UserSettings.
  final metaBox = await Hive.openBox('app_meta');
  final promptsAsked = metaBox.get('notification_prompted') == true;
  if (!promptsAsked) {
    await notifications.requestNotificationPermission();
    await metaBox.put('notification_prompted', true);
  }

  runApp(
    ProviderScope(
      overrides: [
        tasksBoxProvider.overrideWithValue(tasksBox),
        categoriesBoxProvider.overrideWithValue(categoriesBox),
        badgesBoxProvider.overrideWithValue(badgesBox),
        streaksBoxProvider.overrideWithValue(streaksBox),
        settingsBoxProvider.overrideWithValue(settingsBox),
        thematicTextCacheProvider.overrideWithValue(thematicTextCache),
      ],
      child: const SlateApp(),
    ),
  );
}