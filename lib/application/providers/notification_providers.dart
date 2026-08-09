import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/daily_reminder_controller.dart';
import '../services/notification_service.dart';
import '../services/reminder_manager.dart';

/// Servicio real de notificaciones (singleton: el plugin de Flutter es global).
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService.instance;
});

/// Gestor de recordatorios que usa el servicio real de notificaciones.
final reminderManagerProvider = Provider<ReminderManager>((ref) {
  return ReminderManager(scheduler: ref.watch(notificationServiceProvider));
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