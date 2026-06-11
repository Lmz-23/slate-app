import 'package:equatable/equatable.dart';
import '../enums/app_theme_mode.dart';

class UserSettings extends Equatable {
  final String id;
  final String userName;
  final int dayResetHour;
  final bool notificationsEnabled;
  final AppThemeMode themeMode;
  final List<String> unlockedThemeIds;

  const UserSettings({
    this.id = 'singleton',
    this.userName = 'Usuario',
    this.dayResetHour = 4,
    this.notificationsEnabled = true,
    this.themeMode = AppThemeMode.dark,
    this.unlockedThemeIds = const [],
  });

  UserSettings copyWith({
    String? id,
    String? userName,
    int? dayResetHour,
    bool? notificationsEnabled,
    AppThemeMode? themeMode,
    List<String>? unlockedThemeIds,
  }) {
    return UserSettings(
      id: id ?? this.id,
      userName: userName ?? this.userName,
      dayResetHour: dayResetHour ?? this.dayResetHour,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      themeMode: themeMode ?? this.themeMode,
      unlockedThemeIds: unlockedThemeIds ?? this.unlockedThemeIds,
    );
  }

  @override
  List<Object?> get props => [id, userName, dayResetHour, notificationsEnabled, themeMode, unlockedThemeIds];
}