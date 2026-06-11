import 'package:hive_flutter/hive_flutter.dart';
import '../adapters/user_settings_adapter.dart';
import '../../../domain/entities/user_settings.dart';

class SettingsBox {
  static const String _boxName = 'settings';
  static const String _singletonId = 'user_settings';
  late Box<UserSettings> _box;

  Future<void> init() async {
    _box = await Hive.openBox<UserSettings>(_boxName);
  }

  Box<UserSettings> get box => _box;

  UserSettings getSettings() {
    final settings = _box.get(_singletonId);
    if (settings == null) {
      final defaultSettings = const UserSettings();
      _box.put(_singletonId, defaultSettings);
      return defaultSettings;
    }
    return settings;
  }

  Future<void> updateSettings(UserSettings settings) async {
    await _box.put(_singletonId, settings);
  }
}