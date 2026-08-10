import 'package:hive/hive.dart';
import '../../../domain/enums/task_priority.dart';
import '../../../domain/enums/recurrence_type.dart';
import '../../../domain/entities/task.dart';

class TaskAdapter extends TypeAdapter<Task> {
  @override
  final int typeId = 0;

  @override
  Task read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      final key = reader.readByte();
      final value = reader.read();
      fields[key] = value;
    }
    return Task(
      id: fields[0] as String,
      title: fields[1] as String,
      notes: fields[2] as String?,
      scheduledTime: fields[3] as DateTime?,
      scheduledDate: fields[4] as DateTime,
      isCompleted: fields[5] as bool? ?? false,
      priority: TaskPriority.values[fields[6] as int? ?? 0],
      recurrence: RecurrenceType.values[fields[7] as int? ?? 0],
      recurrenceDays: (fields[8] as List?)?.cast<int>(),
      categoryId: fields[9] as String?,
      createdAt: fields[10] as DateTime,
      completedAt: fields[11] as DateTime?,
      parentTaskId: fields[12] as String?,
      // F4: campos nuevos con retrocompatibilidad — si el dato persistido se
      // escribió antes de F4 (13 campos) faltan las claves 13/14 y el `??`
      // devuelve los valores por defecto (false).
      isSubtask: fields[13] as bool? ?? false,
      subtaskXpGranted: fields[14] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, Task obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.notes)
      ..writeByte(3)
      ..write(obj.scheduledTime)
      ..writeByte(4)
      ..write(obj.scheduledDate)
      ..writeByte(5)
      ..write(obj.isCompleted)
      ..writeByte(6)
      ..write(obj.priority.index)
      ..writeByte(7)
      ..write(obj.recurrence.index)
      ..writeByte(8)
      ..write(obj.recurrenceDays)
      ..writeByte(9)
      ..write(obj.categoryId)
      ..writeByte(10)
      ..write(obj.createdAt)
      ..writeByte(11)
      ..write(obj.completedAt)
      ..writeByte(12)
      ..write(obj.parentTaskId)
      ..writeByte(13)
      ..write(obj.isSubtask)
      ..writeByte(14)
      ..write(obj.subtaskXpGranted);
  }
}