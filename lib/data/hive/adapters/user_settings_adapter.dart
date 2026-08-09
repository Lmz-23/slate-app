import 'package:hive/hive.dart';
import '../../../domain/enums/app_theme_mode.dart';
import '../../../domain/entities/user_settings.dart';

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

    final customBadgeConfigsList = fields[15] as List?;
    final customBadgeConfigs = customBadgeConfigsList
        ?.map((e) => CustomBadgeConfig(
              badgeType: e['badgeType'] ?? '',
              customName: e['customName'] ?? '',
              iconName: e['iconName'] ?? '',
              daysRequired: e['daysRequired'] ?? 0,
            ))
        .toList();

    return UserSettings(
      id: fields[0] as String? ?? 'singleton',
      userName: fields[1] as String? ?? 'Usuario',
      dayResetHour: fields[2] as int? ?? 4,
      notificationsEnabled: fields[3] as bool? ?? true,
      themeMode: AppThemeMode.values[fields[4] as int? ?? 0],
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
      customBadgeConfigs: customBadgeConfigs ?? [],
      // Campos añadidos en esta versión (migración hacia delante segura: los
      // registros antiguos no los escriben y aquí se aplica el default).
      notificationLeadTimeMinutes: fields[16] as int? ?? 0,
      dailyReminderEnabled: fields[17] as bool? ?? true,
      dailyReminderHour1: fields[18] as int? ?? 10,
      dailyReminderHour2: fields[19] as int? ?? 19,
    );
  }

  @override
  void write(BinaryWriter writer, UserSettings obj) {
    writer
      ..writeByte(20)
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
      ..writeByte(15)
      ..write(obj.customBadgeConfigs
          .map((e) => {
                'badgeType': e.badgeType,
                'customName': e.customName,
                'iconName': e.iconName,
                'daysRequired': e.daysRequired,
              })
          .toList())
      ..writeByte(16)
      ..write(obj.notificationLeadTimeMinutes)
      ..writeByte(17)
      ..write(obj.dailyReminderEnabled)
      ..writeByte(18)
      ..write(obj.dailyReminderHour1)
      ..writeByte(19)
      ..write(obj.dailyReminderHour2);
  }
}
