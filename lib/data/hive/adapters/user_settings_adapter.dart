import 'package:hive/hive.dart';
import '../../../domain/enums/app_theme_mode.dart';
import '../../../domain/entities/user_settings.dart';

/// Migración segura del ordinal guardado de [AppThemeMode].
///
/// Los registros antiguos pueden contener el ordinal 2 (antiguo
/// `AppThemeMode.system`). Ese valor ya no existe en el enum: se interpreta
/// como `dark`, que es la identidad de Slate. También se protege contra
/// cualquier índice fuera de rango para que un dato corrupto nunca lance un
/// crash al leer los ajustes.
AppThemeMode _themeModeFromStoredIndex(int? index) {
  if (index == null || index < 0 || index >= AppThemeMode.values.length) {
    return AppThemeMode.dark;
  }
  return AppThemeMode.values[index];
}

class UserSettingsAdapter extends TypeAdapter<UserSettings> {
  @override
  final int typeId = 6;

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
      themeMode: _themeModeFromStoredIndex(fields[4] as int?),
      unlockedThemeIds: (fields[5] as List?)?.cast<String>() ?? [],
      timezone: fields[6] as String? ?? 'America/Bogota',
      autoDetectTimezone: fields[7] as bool? ?? false,
      locationPermissionGranted: fields[8] as bool? ?? false,
      useAINotifications: fields[9] as bool? ?? false,
      notificationSound: fields[10] as bool? ?? true,
      notificationVibration: fields[11] as bool? ?? true,
      notificationBadge: fields[12] as bool? ?? true,
      notificationImagePaths: (fields[13] as List?)?.cast<String>() ?? [],
      notificationTextContext: fields[14] as String?,
      // Campos añadidos en esta versión (migración hacia delante segura: los
      // registros antiguos no los escriben y aquí se aplica el default).
      notificationLeadTimeMinutes: fields[16] as int? ?? 0,
      dailyReminderEnabled: fields[17] as bool? ?? true,
      dailyReminderHour1: fields[18] as int? ?? 10,
      dailyReminderHour2: fields[19] as int? ?? 19,
      useAIThematicTexts: fields[21] as bool? ?? false,
      enableDayClosure: fields[22] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, UserSettings obj) {
    writer
      ..writeByte(21)
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
      ..write(obj.unlockedThemeIds)
      ..writeByte(6)
      ..write(obj.timezone)
      ..writeByte(7)
      ..write(obj.autoDetectTimezone)
      ..writeByte(8)
      ..write(obj.locationPermissionGranted)
      ..writeByte(9)
      ..write(obj.useAINotifications)
      ..writeByte(10)
      ..write(obj.notificationSound)
      ..writeByte(11)
      ..write(obj.notificationVibration)
      ..writeByte(12)
      ..write(obj.notificationBadge)
      ..writeByte(13)
      ..write(obj.notificationImagePaths)
      ..writeByte(14)
      ..write(obj.notificationTextContext)
      ..writeByte(16)
      ..write(obj.notificationLeadTimeMinutes)
      ..writeByte(17)
      ..write(obj.dailyReminderEnabled)
      ..writeByte(18)
      ..write(obj.dailyReminderHour1)
      ..writeByte(19)
      ..write(obj.dailyReminderHour2)
      ..writeByte(21)
      ..write(obj.useAIThematicTexts)
      ..writeByte(22)
      ..write(obj.enableDayClosure);
  }
}
