import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/user_settings.dart';
import '../../domain/enums/app_theme_mode.dart';
import '../../data/hive/boxes/settings_box.dart';
import '../../data/repositories/settings_repository_impl.dart';

final settingsBoxProvider = Provider<SettingsBox>((ref) {
  throw UnimplementedError('Must be overridden');
});

final settingsRepositoryProvider = Provider<SettingsRepositoryImpl>((ref) {
  return SettingsRepositoryImpl(ref.watch(settingsBoxProvider));
});

final settingsProvider = StateNotifierProvider<SettingsNotifier, UserSettings>((ref) {
  return SettingsNotifier(ref.watch(settingsRepositoryProvider));
});

class SettingsNotifier extends StateNotifier<UserSettings> {
  final SettingsRepositoryImpl _repository;

  SettingsNotifier(this._repository) : super(_repository.getSettings());

  void refresh() {
    state = _repository.getSettings();
  }

  Future<void> updateUserName(String name) async {
    final updated = state.copyWith(userName: name);
    await _repository.updateSettings(updated);
    state = updated;
  }

  Future<void> updateDayResetHour(int hour) async {
    final updated = state.copyWith(dayResetHour: hour);
    await _repository.updateSettings(updated);
    state = updated;
  }

  Future<void> updateNotificationsEnabled(bool enabled) async {
    final updated = state.copyWith(notificationsEnabled: enabled);
    await _repository.updateSettings(updated);
    state = updated;
  }

  Future<void> updateThemeMode(AppThemeMode mode) async {
    final updated = state.copyWith(themeMode: mode);
    await _repository.updateSettings(updated);
    state = updated;
  }

  Future<void> unlockTheme(String themeId) async {
    if (!state.unlockedThemeIds.contains(themeId)) {
      final updated = state.copyWith(
        unlockedThemeIds: [...state.unlockedThemeIds, themeId],
      );
      await _repository.updateSettings(updated);
      state = updated;
    }
  }

  Future<void> updateTimezone(String timezone) async {
    final updated = state.copyWith(timezone: timezone);
    await _repository.updateSettings(updated);
    state = updated;
  }

  Future<void> updateAutoDetectTimezone(bool enabled) async {
    final updated = state.copyWith(autoDetectTimezone: enabled);
    await _repository.updateSettings(updated);
    state = updated;
  }

  // Recordatorios (P2/P3/P5)
  Future<void> updateNotificationLeadTime(int minutes) async {
    final updated = state.copyWith(notificationLeadTimeMinutes: minutes);
    await _repository.updateSettings(updated);
    state = updated;
  }

  Future<void> updateDailyReminderEnabled(bool enabled) async {
    final updated = state.copyWith(dailyReminderEnabled: enabled);
    await _repository.updateSettings(updated);
    state = updated;
  }

  Future<void> updateDailyReminderHour1(int hour) async {
    final updated = state.copyWith(dailyReminderHour1: hour);
    await _repository.updateSettings(updated);
    state = updated;
  }

  Future<void> updateDailyReminderHour2(int hour) async {
    final updated = state.copyWith(dailyReminderHour2: hour);
    await _repository.updateSettings(updated);
    state = updated;
  }

  Future<void> updateLocationPermissionGranted(bool granted) async {
    final updated = state.copyWith(locationPermissionGranted: granted);
    await _repository.updateSettings(updated);
    state = updated;
  }

  // AI Notification Settings
  Future<void> updateUseAINotifications(bool useAI) async {
    final updated = state.copyWith(useAINotifications: useAI);
    await _repository.updateSettings(updated);
    state = updated;
  }

  Future<void> updateNotificationSound(bool sound) async {
    final updated = state.copyWith(notificationSound: sound);
    await _repository.updateSettings(updated);
    state = updated;
  }

  Future<void> updateNotificationVibration(bool vibration) async {
    final updated = state.copyWith(notificationVibration: vibration);
    await _repository.updateSettings(updated);
    state = updated;
  }

  Future<void> updateNotificationBadge(bool badge) async {
    final updated = state.copyWith(notificationBadge: badge);
    await _repository.updateSettings(updated);
    state = updated;
  }

  Future<void> updateNotificationContext({
    List<String>? imagePaths,
    String? textContext,
  }) async {
    final updated = state.copyWith(
      notificationImagePaths: imagePaths,
      notificationTextContext: textContext,
    );
    await _repository.updateSettings(updated);
    state = updated;
  }

  Future<void> applyAINotificationSettings({
    required bool sound,
    required bool vibration,
    required bool badge,
  }) async {
    final updated = state.copyWith(
      notificationSound: sound,
      notificationVibration: vibration,
      notificationBadge: badge,
    );
    await _repository.updateSettings(updated);
    state = updated;
  }

  // Badge Customization
  Future<void> updateCustomBadgeConfig(CustomBadgeConfig config) async {
    final existing = state.customBadgeConfigs
        .where((c) => c.badgeType == config.badgeType)
        .toList();

    List<CustomBadgeConfig> newConfigs;
    if (existing.isNotEmpty) {
      newConfigs = state.customBadgeConfigs.map((c) {
        return c.badgeType == config.badgeType ? config : c;
      }).toList();
    } else {
      newConfigs = [...state.customBadgeConfigs, config];
    }

    final updated = state.copyWith(customBadgeConfigs: newConfigs);
    await _repository.updateSettings(updated);
    state = updated;
  }

  Future<void> addCustomBadge(CustomBadgeConfig config) async {
    final updated = state.copyWith(
      customBadgeConfigs: [...state.customBadgeConfigs, config],
    );
    await _repository.updateSettings(updated);
    state = updated;
  }
}
