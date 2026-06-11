import 'package:hive/hive.dart';
import '../../../domain/enums/badge_type.dart';
import '../../../domain/entities/badge.dart';

class BadgeAdapter extends TypeAdapter<Badge> {
  @override
  final int typeId = 2;

  @override
  Badge read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      final key = reader.readByte();
      final value = reader.read();
      fields[key] = value;
    }
    return Badge(
      id: fields[0] as String,
      type: BadgeType.values[fields[1] as int],
      name: fields[2] as String,
      iconName: fields[3] as String,
      unlockedAt: fields[4] as DateTime,
      isDisplayed: fields[5] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, Badge obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type.index)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.iconName)
      ..writeByte(4)
      ..write(obj.unlockedAt)
      ..writeByte(5)
      ..write(obj.isDisplayed);
  }
}