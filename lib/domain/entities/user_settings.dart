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
