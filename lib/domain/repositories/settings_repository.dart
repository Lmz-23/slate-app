import '../entities/user_settings.dart';

abstract class SettingsRepository {
  UserSettings getSettings();
  Future<void> updateSettings(UserSettings settings);
}