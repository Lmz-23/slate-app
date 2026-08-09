import '../../domain/entities/user_settings.dart';

/// Configuración EFECTIVA del canal de notificaciones derivada de los ajustes
/// del usuario (toggles de sonido/vibración/badge).
///
/// Es un objeto de valor plano (sin dependencias de plugin ni de Riverpod)
/// para que la lógica de derivación sea directamente testeable.
class ReminderChannelSettings {
  const ReminderChannelSettings({
    required this.playSound,
    required this.enableVibration,
    required this.showBadge,
    required this.presentSound,
    required this.presentBadge,
  });

  /// Android: ¿debe sonar el recordatorio? (`playSound` del canal).
  final bool playSound;

  /// Android: ¿debe vibrar el recordatorio? (`enableVibration` del canal).
  final bool enableVibration;

  /// Android: ¿debe sumar al badge del Launcher? (`showBadge` del canal).
  final bool showBadge;

  /// iOS/macOS: ¿debe presentarse con sonido? (`presentSound`).
  final bool presentSound;

  /// iOS/macOS: ¿debe actualizar el badge? (`presentBadge`).
  final bool presentBadge;
}

/// Lógica PURA que traduce los toggles de [UserSettings] a la configuración
/// del canal único `task_reminders`.
///
/// Comportamiento documentado:
/// - `notificationSound == false` → recordatorios SILENCIOSOS: `playSound`
///   (y `presentSound` en iOS) quedan a false.
/// - `notificationVibration == false` → `enableVibration=false`. ADEMÁS, en
///   Android desactivar la vibración en un canal también desactiva su sonido
///   (comportamiento del sistema, no de la app), por lo que `playSound`
///   también queda a false aunque el usuario tenga el sonido activo.
///   En iOS no existe un control independiente de vibración: el sonido sigue
///   el toggle de sonido (`presentSound`).
/// - `notificationBadge == false` → `showBadge=false` (`presentBadge=false`).
class ReminderChannelSettingsCalculator {
  const ReminderChannelSettingsCalculator._();

  static const String channelId = 'task_reminders';

  static ReminderChannelSettings fromSettings(UserSettings settings) {
    final keepVibration = settings.notificationVibration;
    // Regla Android: sin vibración no hay sonido en el canal.
    final androidSound = settings.notificationSound && keepVibration;

    return ReminderChannelSettings(
      playSound: androidSound,
      enableVibration: keepVibration,
      showBadge: settings.notificationBadge,
      presentSound: settings.notificationSound,
      presentBadge: settings.notificationBadge,
    );
  }
}