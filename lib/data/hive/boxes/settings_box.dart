import 'package:hive_flutter/hive_flutter.dart';
import '../../../domain/entities/user_settings.dart';

class SettingsBox {
  static const String _boxName = 'settings';

  /// Key bajo el que se guarda el ajuste del usuario (visible para el backup).
  static const String singletonBoxKey = 'user_settings';

  static const String _singletonId = singletonBoxKey;
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