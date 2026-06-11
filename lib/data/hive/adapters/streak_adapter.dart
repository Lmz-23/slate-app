import 'package:hive/hive.dart';
import '../../../domain/entities/streak.dart';

class StreakAdapter extends TypeAdapter<Streak> {
  @override
  final int typeId = 3;

  @override
  Streak read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      final key = reader.readByte();
      final value = reader.read();
      fields[key] = value;
    }
    return Streak(
      id: fields[0] as String,
      currentStreak: fields[1] as int? ?? 0,
      longestStreak: fields[2] as int? ?? 0,
      lastCompletedDate: fields[3] as DateTime?,
      updatedAt: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Streak obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.currentStreak)
      ..writeByte(2)
      ..write(obj.longestStreak)
      ..writeByte(3)
      ..write(obj.lastCompletedDate)
      ..writeByte(4)
      ..write(obj.updatedAt);
  }
}