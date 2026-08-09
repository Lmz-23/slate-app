/// Contrato de bajo nivel para programar/cancelar notificaciones.
///
/// Está separado de la implementación con `flutter_local_notifications` para
/// poder inyectar un FAKE en los tests de lógica ([ReminderManager]) sin
/// depender del plugin nativo (que no existe en el entorno de `flutter test`).
abstract interface class ReminderScheduler {
  /// Inicializa el servicio y fija la zona horaria [timezone].
  Future<void> init({required String timezone});

  /// ¿El dispositivo permite programar alarmas EXACTAS? (Android 12+ /
  /// Android 13+).
  Future<bool> canScheduleExactNotifications();

  /// Solicita al usuario el permiso de alarmas exactas (Android 12+).
  Future<bool> requestExactAlarmsPermission();

  /// Programa la notificación [id] para [fireTime] con [title]/[body].
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime fireTime,
  });

  /// Cancela la notificación [id] (programada o mostrada).
  Future<void> cancel(int id);
}