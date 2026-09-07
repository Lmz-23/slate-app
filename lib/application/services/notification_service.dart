import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/entities/user_settings.dart';
import 'channel_details_calculator.dart';
import 'reminder_scheduler.dart';

/// Implementación real del sistema de notificaciones con
/// `flutter_local_notifications`.
///
/// Décisiones técnicas:
/// - Zona horaria: en `init` y/o `updateTimezone` se fija `tz.local` con la
///   zona configurada por el usuario. Sin esto, `zonedSchedule` interpretaría
///   los instantes en UTC y los recordatorios se dispararían a otra hora.
/// - Alarmas exactas: priorizamos `AndroidScheduleMode.exactAllowWhileIdle`.
///   Antes de programar se comprueba `canScheduleExactNotifications()` (Android
///   12+ / Android 13+). Si no se puede, se solicita el permiso
///   (`SCHEDULE_EXACT_ALARM`). Si el usuario no lo concede, se usa
///   `inexactAllowWhileIdle` como FALLBACK para no perder el recordatorio.
/// - Canal único `task_reminders` para recordatorios de tareas y resúmenes
///   diarios (importancia alta).
class NotificationService implements ReminderScheduler {
  static final NotificationService instance = NotificationService._internal();

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  String _timezone = 'UTC';
  AndroidFlutterLocalNotificationsPlugin? _androidPlugin;

  /// Sonido/vibración/badge EFECTIVOS del canal único derivados de los ajustes
  /// del usuario (Mejora 2). Se usa tanto para crear/recrear el canal como
  /// para construir los `NotificationDetails` de cada `zonedSchedule`.
  ReminderChannelSettings _channelSettings =
      ReminderChannelSettingsCalculator.fromSettings(const UserSettings());

  /// Resultado cacheado de `canScheduleExactNotifications()` (una consulta
  /// nativa por sesión, no una por `schedule()`). Durante el arranque con N
  /// tareas cada programación hacía un round trip redundante al hilo de
  /// plataforma; con la caché la primera llamada decide y el resto reutiliza.
  ///
  /// Solo se cachea cuando el plugin Android está inicializado: si se llamara
  /// antes de `init()`, el `false` provisional sería incorrecto para el resto
  /// de la sesión.
  ///
  /// Si el usuario revoca el permiso de alarmas exactas desde Ajustes del
  /// sistema mientras la app corre, `schedule()` seguiría usando
  /// `exactAllowWhileIdle` según el valor cacheado (caso raro; el fallback
  /// `inexactAllowWhileIdle` solo aplica cuando el valor es `false`). No hay
  /// hook de lifecycle en la app para re-comprobar; el servicio se reinicia
  /// con la app.
  bool? _canScheduleExact;

  bool get isInitialized => _initialized;

  /// Configuración efectiva del canal (lectura para observabilidad/tests).
  /// `playSound` respeta la regla Android de que sin vibración no hay sonido.
  ReminderChannelSettings get channelSettings => _channelSettings;

  /// Inicializa el plugin, la base de datos de zonas horarias y fija la hora
  /// local a la zona [timezone] configurada por el usuario.
  ///
  /// Si se aportan [settings] (ajustes persistidos), deriva de ellos el canal
  /// y lo Crea/recrea en el sistema, de modo que los toggles de sonido,
  /// vibración y badge se aplican desde el arranque.
  ///
  /// Idempotente: solo ejecuta la inicialización una vez.
  @override
  Future<void> init({
    required String timezone,
    UserSettings? settings,
  }) async {
    _timezone = timezone;
    _channelSettings = ReminderChannelSettingsCalculator.fromSettings(
        settings ?? const UserSettings());
    if (_initialized) return;

    tz_data.initializeTimeZones();
    _setLocalTimezone(timezone);

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(initSettings);
    _androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    _initialized = true;

    // En Android 8+ sonido/vibración/badge se fijan EN EL CANAL al crearlo,
    // no por notificación. Se crea aquí para que la configuración del usuario
    // quede activa desde el primer arranque.
    await _createAndroidChannel();
  }

  /// Re-aplica la configuración del canal (sonido/vibración/badge) cuando el
  /// usuario cambia esos ajustes. Recrea el canal `task_reminders` para que la
  /// nueva configuración se aplique a los PRÓXIMOS recordatorios al instante.
  ///
  /// Nota técnica: `flutter_local_notifications` solo aplica `playSound` /
  /// `enableVibration` / `showBadge` cuando CREA el canal; si ya existía no
  /// se tocan. Por eso se debe invocar `createNotificationChannel` (mismo id,
  /// nueva config) al cambiar los toggles, y conviene también re-agendar los
  /// recordatorios con los nuevos detalles (lo hace [scheduler] al regenerar).
  Future<void> updateChannelForSettings(UserSettings settings) async {
    _channelSettings = ReminderChannelSettingsCalculator.fromSettings(settings);
    await _createAndroidChannel();
  }

  /// Crea (o re-crea) el canal único `task_reminders` con la configuración
  /// derivada de los ajustes. No-op silencioso si el plugin Android aún no está
  /// inicializado (p. ej. en tests sin plataforma).
  Future<void> _createAndroidChannel() async {
    final plugin = _androidPlugin;
    if (plugin == null) return;
    try {
      await plugin.createNotificationChannel(
        AndroidNotificationChannel(
          ReminderChannelSettingsCalculator.channelId,
          'Recordatorios de tareas',
          description: 'Notificaciones para recordatorios de tareas',
          importance: Importance.high,
          playSound: _channelSettings.playSound,
          enableVibration: _channelSettings.enableVibration,
          showBadge: _channelSettings.showBadge,
        ),
      );
    } catch (e) {
      debugPrint('NotificationService: error creando canal: $e');
    }
  }

  /// Re-apunta la zona horaria de los `zonedSchedule` cuando el usuario cambia
  /// de zona en Ajustes.
  void updateTimezone(String timezone) {
    if (timezone == _timezone) return;
    _timezone = timezone;
    if (_initialized) _setLocalTimezone(timezone);
  }

  void _setLocalTimezone(String timezone) {
    try {
      tz.setLocalLocation(tz.getLocation(timezone));
    } catch (_) {
      // Zona inválida: se conserva `tz.local` (puede seguir sin fijar si no se
      // ha podido detectar; tz.local cae a UTC en ese caso).
    }
  }

  /// Instante `fireTime` interpretado en la zona configurada por el usuario.
  tz.TZDateTime _tzNow(DateTime fireTime) {
    try {
      return tz.TZDateTime.from(fireTime, tz.getLocation(_timezone));
    } catch (_) {
      return tz.TZDateTime.from(fireTime, tz.UTC);
    }
  }

  @override
  Future<bool> canScheduleExactNotifications() async {
    final cached = _canScheduleExact;
    if (cached != null) return cached;
    final plugin = _androidPlugin;
    if (plugin == null) return false;
    final result = await plugin.canScheduleExactNotifications();
    final value = result ?? false;
    _canScheduleExact = value;
    return value;
  }

  @override
  Future<bool> requestExactAlarmsPermission() async {
    final plugin = _androidPlugin;
    if (plugin == null) return false;
    final result = await plugin.requestExactAlarmsPermission();
    return result ?? false;
  }

  /// Estado actual del permiso POST_NOTIFICATIONS.
  Future<PermissionStatus> notificationPermissionStatus() =>
      Permission.notification.status;

  /// Solicita el permiso POST_NOTIFICATIONS. Devuelve si quedó concedido.
  Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime fireTime,
  }) async {
    // Alarmas exactas cuando el dispositivo lo permite; fallback a inexacta.
    bool exact = false;
    try {
      exact = await canScheduleExactNotifications();
    } catch (_) {
      exact = false;
    }
    final scheduleMode = exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    // Mejora 2: los NotificationDetails se construyen con los toggles del
    // usuario. Sonido/vibración/badge se aplican en el canal (Android 8+);
    // `zonedSchedule` con estos detalles sirve además de confirmación para
    // notificaciones individuales.
    final channel = _channelSettings;
    final androidDetails = AndroidNotificationDetails(
      ReminderChannelSettingsCalculator.channelId,
      'Recordatorios de tareas',
      channelDescription: 'Notificaciones para recordatorios de tareas',
      importance: Importance.high,
      priority: Priority.high,
      playSound: channel.playSound,
      enableVibration: channel.enableVibration,
    );
    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: channel.presentBadge,
      presentSound: channel.presentSound,
    );
    final details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      _tzNow(fireTime),
      details,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: scheduleMode,
    );
  }

  @override
  Future<void> cancel(int id) => _notifications.cancel(id);

  /// Cancela todas las notificaciones (programadas y mostradas).
  Future<void> cancelAll() => _notifications.cancelAll();
}
