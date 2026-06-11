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
}