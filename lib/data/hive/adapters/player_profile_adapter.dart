import 'package:hive/hive.dart';
import '../../../domain/entities/player_profile.dart';

/// TypeAdapter de [PlayerProfile] para la caja `player_progress`.
///
/// typeId libre **4**: ocupados 0 (Task), 1 (Category), 2 (Badge),
/// 3 (Streak), 6 (UserSettings).
///
/// `shownLevelUps` se serializa como `List<int>` (Hive almacena listas de
/// primitivas de forma nativa) y se reconstruye como `Set<int>` en memoria.
class PlayerProfileAdapter extends TypeAdapter<PlayerProfile> {
  @override
  final int typeId = 4;

  @override
  PlayerProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      final key = reader.readByte();
      final value = reader.read();
      fields[key] = value;
    }
    return PlayerProfile(
      id: fields[0] as String,
      totalXp: fields[1] as int? ?? 0,
      level: fields[2] as int? ?? 1,
      shownLevelUps: ((fields[3] as List?) ?? const []).cast<int>().toSet(),
      updatedAt: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, PlayerProfile obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.totalXp)
      ..writeByte(2)
      ..write(obj.level)
      ..writeByte(3)
      ..write(obj.shownLevelUps.toList())
      ..writeByte(4)
      ..write(obj.updatedAt);
  }
}