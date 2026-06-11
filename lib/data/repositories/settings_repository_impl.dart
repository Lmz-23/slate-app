import '../../domain/entities/user_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import '../hive/boxes/settings_box.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final SettingsBox _settingsBox;

  SettingsRepositoryImpl(this._settingsBox);

  @override
  UserSettings getSettings() => _settingsBox.getSettings();

  @override
  Future<void> updateSettings(UserSettings settings) => _settingsBox.updateSettings(settings);
}