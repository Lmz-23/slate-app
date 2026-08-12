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
import 'data/hive/adapters/player_profile_adapter.dart';
import 'data/hive/adapters/companion_state_adapter.dart';
import 'data/hive/boxes/tasks_box.dart';
import 'data/hive/boxes/categories_box.dart';
import 'data/hive/boxes/badges_box.dart';
import 'data/hive/boxes/streaks_box.dart';
import 'data/hive/boxes/settings_box.dart';
import 'data/hive/boxes/thematic_text_cache_box.dart';
import 'data/hive/boxes/player_progress_box.dart';
import 'data/hive/boxes/companion_state_box.dart';
import 'application/providers/task_provider.dart';
import 'application/providers/category_provider.dart';
import 'application/providers/streak_provider.dart';
import 'application/providers/settings_provider.dart';
import 'application/providers/player_provider.dart';
import 'application/providers/quest_provider.dart';
import 'application/providers/notification_providers.dart';
import 'application/providers/backup_provider.dart';
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
  Hive.registerAdapter(PlayerProfileAdapter());
  Hive.registerAdapter(CompanionStateAdapter());

  final tasksBox = TasksBox();
  final categoriesBox = CategoriesBox();
  final badgesBox = BadgesBox();
  final streaksBox = StreaksBox();
  final settingsBox = SettingsBox();

  // Perfil de Jugador (F2): caja `player_progress` con XP/nivel. Se abre antes
  // de runApp para que `playerProvider` pueda leerlo desde el primer frame.
  final playerProgressBox = PlayerProgressBox();

  // Estado del Sistema (F3): caja `companion_state` con la quest diaria. Se
  // abre antes de runApp para que `questProvider` pueda leerlo al instante.
  final companionStateBox = CompanionStateBox();

  // Caché local de variantes temáticas (Slate System) generadas con IA. Se
  // abre antes de runApp para que el resolver pueda leerla al programar.
  final thematicTextCache = ThematicTextCache();

  // Las 8 cajas se abren EN PARALELO: cada `openBox` decodifica sus objetos en
  // el UI isolate y la apertura secuencial sumaba su latencia al cold start.
  // Hive soporta apertura concurrente de boxes DISTINTOS (cada uno es un
  // archivo independiente); los adapters ya están registrados arriba.
  await Future.wait([
    tasksBox.init(),
    categoriesBox.init(),
    badgesBox.init(),
    streaksBox.init(),
    settingsBox.init(),
    playerProgressBox.init(),
    companionStateBox.init(),
    thematicTextCache.init(),
  ]);

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
        playerProgressBoxProvider.overrideWithValue(playerProgressBox),
        companionStateBoxProvider.overrideWithValue(companionStateBox),
        thematicTextCacheProvider.overrideWithValue(thematicTextCache),
        appMetaBoxProvider.overrideWithValue(metaBox),
      ],
      child: const SlateApp(),
    ),
  );
}
