import 'package:equatable/equatable.dart';
import '../enums/app_theme_mode.dart';

class UserSettings extends Equatable {
  final String id;
  final String userName;
  final int dayResetHour;
  final bool notificationsEnabled;
  final AppThemeMode themeMode;
  final List<String> unlockedThemeIds;
  final String timezone;
  final bool autoDetectTimezone;
  final bool locationPermissionGranted;

  // AI Notification Settings
  final bool useAINotifications;
  final bool notificationSound;
  final bool notificationVibration;
  final bool notificationBadge;
  final List<String> notificationImagePaths;
  final String? notificationTextContext;

  // AI Badge Settings
  final List<CustomBadgeConfig> customBadgeConfigs;

  // Recordatorios de tarea / resumen diario (P2/P3/P5)
  /// Margen de aviso ANTES de la hora de la tarea (minutos). Default 0: se
  /// avisa justo a la hora de la tarea.
  final int notificationLeadTimeMinutes;

  /// Activa/desactiva los resúmenes diarios (10:00 y 19:00).
  final bool dailyReminderEnabled;
  final int dailyReminderHour1;
  final int dailyReminderHour2;

  // Slate System (personalización temática)
  /// Activa la estética temática "Slate System" en notificaciones e insignias
  /// (textos temáticos y nomenclatura de rangos/niveles). Cuando está OFF el
  /// comportamiento y los textos son idénticos a los actuales.
  final bool slateSystemTheme;

  /// Opt-in: genera los textos temáticos de notificaciones con IA (Gemini) al
  /// guardar tareas/generar contenido. Los textos se guardan en caché local en
  /// el dispositivo; si no hay red/API key se usa el catálogo local.
  final bool useAIThematicTexts;

  /// Opt-in: notificación única de cierre de jornada (id `0x60000003`) que se
  /// programa al cruzar de día usando `dayResetHour` (default 04:00).
  final bool enableDayClosure;

  const UserSettings({
    this.id = 'singleton',
    this.userName = 'Usuario',
    this.dayResetHour = 4,
    this.notificationsEnabled = true,
    this.themeMode = AppThemeMode.dark,
    this.unlockedThemeIds = const [],
    this.timezone = 'America/Bogota',
    this.autoDetectTimezone = false,
    this.locationPermissionGranted = false,
    this.useAINotifications = false,
    this.notificationSound = true,
    this.notificationVibration = true,
    this.notificationBadge = true,
    this.notificationImagePaths = const [],
    this.notificationTextContext,
    this.customBadgeConfigs = const [],
    this.notificationLeadTimeMinutes = 0,
    this.dailyReminderEnabled = true,
    this.dailyReminderHour1 = 10,
    this.dailyReminderHour2 = 19,
    this.slateSystemTheme = false,
    this.useAIThematicTexts = false,
    this.enableDayClosure = false,
  });

  UserSettings copyWith({
    String? id,
    String? userName,
    int? dayResetHour,
    bool? notificationsEnabled,
    AppThemeMode? themeMode,
    List<String>? unlockedThemeIds,
    String? timezone,
    bool? autoDetectTimezone,
    bool? locationPermissionGranted,
    bool? useAINotifications,
    bool? notificationSound,
    bool? notificationVibration,
    bool? notificationBadge,
    List<String>? notificationImagePaths,
    String? notificationTextContext,
    List<CustomBadgeConfig>? customBadgeConfigs,
    int? notificationLeadTimeMinutes,
    bool? dailyReminderEnabled,
    int? dailyReminderHour1,
    int? dailyReminderHour2,
    bool? slateSystemTheme,
    bool? useAIThematicTexts,
    bool? enableDayClosure,
  }) {
    return UserSettings(
      id: id ?? this.id,
      userName: userName ?? this.userName,
      dayResetHour: dayResetHour ?? this.dayResetHour,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      themeMode: themeMode ?? this.themeMode,
      unlockedThemeIds: unlockedThemeIds ?? this.unlockedThemeIds,
      timezone: timezone ?? this.timezone,
      autoDetectTimezone: autoDetectTimezone ?? this.autoDetectTimezone,
      locationPermissionGranted: locationPermissionGranted ?? this.locationPermissionGranted,
      useAINotifications: useAINotifications ?? this.useAINotifications,
      notificationSound: notificationSound ?? this.notificationSound,
      notificationVibration: notificationVibration ?? this.notificationVibration,
      notificationBadge: notificationBadge ?? this.notificationBadge,
      notificationImagePaths: notificationImagePaths ?? this.notificationImagePaths,
      notificationTextContext: notificationTextContext ?? this.notificationTextContext,
      customBadgeConfigs: customBadgeConfigs ?? this.customBadgeConfigs,
      notificationLeadTimeMinutes:
          notificationLeadTimeMinutes ?? this.notificationLeadTimeMinutes,
      dailyReminderEnabled: dailyReminderEnabled ?? this.dailyReminderEnabled,
      dailyReminderHour1: dailyReminderHour1 ?? this.dailyReminderHour1,
      dailyReminderHour2: dailyReminderHour2 ?? this.dailyReminderHour2,
      slateSystemTheme: slateSystemTheme ?? this.slateSystemTheme,
      useAIThematicTexts: useAIThematicTexts ?? this.useAIThematicTexts,
      enableDayClosure: enableDayClosure ?? this.enableDayClosure,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userName,
        dayResetHour,
        notificationsEnabled,
        themeMode,
        unlockedThemeIds,
        timezone,
        autoDetectTimezone,
        locationPermissionGranted,
        useAINotifications,
        notificationSound,
        notificationVibration,
        notificationBadge,
        notificationImagePaths,
        notificationTextContext,
        customBadgeConfigs,
        notificationLeadTimeMinutes,
        dailyReminderEnabled,
        dailyReminderHour1,
        dailyReminderHour2,
        slateSystemTheme,
        useAIThematicTexts,
        enableDayClosure,
      ];
}

class CustomBadgeConfig extends Equatable {
  final String badgeType; // e.g., "streak30", "custom90"
  final String customName;
  final String iconName;
  final int daysRequired;

  const CustomBadgeConfig({
    required this.badgeType,
    required this.customName,
    required this.iconName,
    required this.daysRequired,
  });

  CustomBadgeConfig copyWith({
    String? badgeType,
    String? customName,
    String? iconName,
    int? daysRequired,
  }) {
    return CustomBadgeConfig(
      badgeType: badgeType ?? this.badgeType,
      customName: customName ?? this.customName,
      iconName: iconName ?? this.iconName,
      daysRequired: daysRequired ?? this.daysRequired,
    );
  }

  @override
  List<Object?> get props => [badgeType, customName, iconName, daysRequired];
}
