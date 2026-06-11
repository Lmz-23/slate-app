import 'package:hive/hive.dart';
import '../../../domain/enums/app_theme_mode.dart';
import '../../../domain/entities/user_settings.dart';

class UserSettingsAdapter extends TypeAdapter<UserSettings> {
  @override
  final int typeId = 4;

  @override
  UserSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      final key = reader.readByte();
      final value = reader.read();
      fields[key] = value;
    }
    return UserSettings(
      id: fields[0] as String? ?? 'singleton',
      userName: fields[1] as String? ?? 'Usuario',
      dayResetHour: fields[2] as int? ?? 4,
      notificationsEnabled: fields[3] as bool? ?? true,
      themeMode: AppThemeMode.values[fields[4] as int? ?? 0],
      unlockedThemeIds: (fields[5] as List?)?.cast<String>() ?? [],
    );
  }

  @override
  void write(BinaryWriter writer, UserSettings obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userName)
      ..writeByte(2)
      ..write(obj.dayResetHour)
      ..writeByte(3)
      ..write(obj.notificationsEnabled)
      ..writeByte(4)
      ..write(obj.themeMode.index)
      ..writeByte(5)
      ..write(obj.unlockedThemeIds);
  }
}