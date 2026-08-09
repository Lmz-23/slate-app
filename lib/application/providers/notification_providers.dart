import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/hive/boxes/thematic_text_cache_box.dart';
import '../services/ai_service.dart';
import '../services/daily_reminder_controller.dart';
import '../services/notification_service.dart';
import '../services/reminder_manager.dart';
import '../services/thematic_texts_generator.dart';
import '../services/thematic_texts_resolver.dart';

/// Servicio real de notificaciones (singleton: el plugin de Flutter es global).
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService.instance;
});

/// Servicio de IA (Gemini). Instanciable en tests para fake sin plugin nativo.
final aiServiceProvider = Provider<AIService>((ref) => AIService());

/// Caché Hive de variantes temáticas generadas con IA. Por defecto `null` para
/// que los tests/entornos sin Hive funcionen con el catálogo local; `main.dart`
/// lo sobrescribe con una instancia inicializada.
final thematicTextCacheProvider = Provider<ThematicTextCache?>((ref) => null);

/// Generador de variantes temáticas con IA (opcional; no-op sin API key/caché).
final thematicTextsGeneratorProvider = Provider<ThematicTextsGenerator>((ref) {
  return ThematicTextsGenerator(
    aiService: ref.watch(aiServiceProvider),
    cache: ref.watch(thematicTextCacheProvider),
  );
});

/// Resolver de textos temáticos (Slate System). Sin caché/usuario solo usa el
/// catálogo local y devuelve `null` cuando el tema está OFF.
final thematicTextsResolverProvider = Provider<ThematicTextsResolver>((ref) {
  return ThematicTextsResolver(
    cache: ref.watch(thematicTextCacheProvider),
    generator: ref.watch(thematicTextsGeneratorProvider),
  );
});

/// Gestor de recordatorios que usa el servicio real de notificaciones y el
/// resolver de textos temáticos (Slate System).
final reminderManagerProvider = Provider<ReminderManager>((ref) {
  return ReminderManager(
    scheduler: ref.watch(notificationServiceProvider),
    resolver: ref.watch(thematicTextsResolverProvider),
  );
});

/// Controlador del recordatorio diario. Se observa desde `SlateApp` para que
/// viva durante toda la sesión y reaccione a tareas/ajustes/cambio de día.
final dailyReminderControllerProvider = Provider<DailyReminderController>((ref) {
  final controller = DailyReminderController(
    ref,
    ref.watch(reminderManagerProvider),
    ref.watch(notificationServiceProvider),
  );
  ref.onDispose(controller.dispose);
  return controller;
});