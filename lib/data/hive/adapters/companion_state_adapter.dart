import 'package:hive/hive.dart';
import '../../../domain/entities/companion_state.dart';

/// TypeAdapter de [CompanionState] para la caja `companion_state` (F3).
///
/// typeId libre **5**: ocupados 0 (Task), 1 (Category), 2 (Badge),
/// 3 (Streak), 4 (PlayerProfile), 6 (UserSettings).
class CompanionStateAdapter extends TypeAdapter<CompanionState> {
  @override
  final int typeId = 5;

  @override
  CompanionState read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      final key = reader.readByte();
      final value = reader.read();
      fields[key] = value;
    }
    return CompanionState(
      id: fields[0] as String? ?? 'main_companion',
      questClaimedOn: fields[1] as String?,
      questVisibleOn: fields[2] as String?,
      questVisibleDecision: fields[3] as bool? ?? false,
      updatedAt: fields[4] as DateTime? ?? DateTime.now(),
    );
  }

  @override
  void write(BinaryWriter writer, CompanionState obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.questClaimedOn)
      ..writeByte(2)
      ..write(obj.questVisibleOn)
      ..writeByte(3)
      ..write(obj.questVisibleDecision)
      ..writeByte(4)
      ..write(obj.updatedAt);
  }
}