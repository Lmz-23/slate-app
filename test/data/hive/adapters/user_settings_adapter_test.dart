import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:slate_app/data/hive/adapters/user_settings_adapter.dart';
import 'package:slate_app/domain/entities/user_settings.dart';
import 'package:slate_app/domain/enums/app_theme_mode.dart';

/// Lector mínimo del formato binario de Hive limitado a los tipos que usa el
/// adapter de UserSettings y a los formatos EXISTENTES en la versión 1 del
/// adapter (16 campos). Su propósito es verificar la MIGRACIÓN segura: un
/// registro antiguo (escrito con 16 campos) debe poder leerse con el adapter
/// actual, que aplica los defaults de los campos nuevos (16..19).
class _LegacyBytesReader implements BinaryReader {
  _LegacyBytesReader(this._bytes);

  final Uint8List _bytes;
  int _offset = 0;

  @override
  int get availableBytes => _bytes.length - _offset;
  @override
  int get usedBytes => _offset;

  @override
  int readByte() => _bytes[_offset++];

  int _readUint32() {
    final b = _bytes;
    final o = _offset;
    _offset += 4;
    return b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24);
  }

  double _readDouble() {
    final view = ByteData.sublistView(_bytes, _offset, _offset + 8);
    _offset += 8;
    return view.getFloat64(0, Endian.little);
  }

  String _readString() {
    final length = _readUint32();
    final out = utf8.decode(_bytes.sublist(_offset, _offset + length));
    _offset += length;
    return out;
  }

  @override
  dynamic read([int? typeId]) {
    final type = typeId ?? _bytes[_offset++];
    switch (type) {
      case 0: // null
        return null;
      case 1: // int (se almacena como double ascii64)
        return _readDouble().round();
      case 2: // double
        return _readDouble();
      case 3: // bool
        return _bytes[_offset++] == 1;
      case 4: // string
        return _readString();
      case 9: // stringList
        final count = _readUint32();
        return List<String>.generate(count, (_) => _readString());
      case 10: // list genérico
        final count = _readUint32();
        return List<dynamic>.generate(count, (_) => read());
      case 11: // map
        final count = _readUint32();
        return <dynamic, dynamic>{
          for (var i = 0; i < count; i++) read(): read(),
        };
      default:
        throw UnsupportedError('LegacyBytesReader: tipo no soportado $type');
    }
  }

  @override
  void skip(int bytes) => _offset += bytes;

  @override
  Uint8List viewBytes(int bytes) =>
      Uint8List.sublistView(_bytes, _offset, _offset + bytes);

  @override
  Uint8List peekBytes(int bytes) =>
      Uint8List.sublistView(_bytes, _offset, _offset + bytes);

  @override
  int readWord() => throw UnimplementedError();
  @override
  int readInt32() => throw UnimplementedError();
  @override
  int readUint32() => throw UnimplementedError();
  @override
  int readInt() => throw UnimplementedError();
  @override
  double readDouble() => throw UnimplementedError();
  @override
  bool readBool() => throw UnimplementedError();
  @override
  String readString([
    int? byteCount,
    Converter<List<int>, String> decoder = BinaryReader.utf8Decoder,
  ]) =>
      throw UnimplementedError();
  @override
  Uint8List readByteList([int? length]) => throw UnimplementedError();
  @override
  List<int> readIntList([int? length]) => throw UnimplementedError();
  @override
  List<double> readDoubleList([int? length]) => throw UnimplementedError();
  @override
  List<bool> readBoolList([int? length]) => throw UnimplementedError();
  @override
  List<String> readStringList([
    int? length,
    Converter<List<int>, String> decoder = BinaryReader.utf8Decoder,
  ]) =>
      throw UnimplementedError();
  @override
  List readList([int? length]) => throw UnimplementedError();
  @override
  Map readMap([int? length]) => throw UnimplementedError();
  @override
  HiveList readHiveList([int? length]) => throw UnimplementedError();
}

/// Emula byte a byte lo que escribía el adapter V1 (16 campos) siguiendo el
/// mismo formato binario de Hive.
Uint8List legacy16FieldBytes() {
  final builder = BytesBuilder();

  void byte(int v) => builder.addByte(v);

  void u32(int v) {
    builder
      ..addByte(v & 0xFF)
      ..addByte((v >> 8) & 0xFF)
      ..addByte((v >> 16) & 0xFF)
      ..addByte((v >> 24) & 0xFF);
  }

  void f64(double v) {
    final bd = ByteData(8)..setFloat64(0, v, Endian.little);
    builder.add(bd.buffer.asUint8List());
  }

  void str(String s) {
    final bytes = utf8.encode(s);
    u32(bytes.length);
    builder.add(bytes);
  }

  void value(dynamic v) {
    if (v == null) {
      byte(0);
    } else if (v is bool) {
      byte(3);
      byte(v ? 1 : 0);
    } else if (v is int) {
      byte(1);
      f64(v.toDouble());
    } else if (v is String) {
      byte(4);
      str(v);
    } else if (v is List<String> && v.isEmpty) {
      // Lista vacía List<String> -> stringList
      byte(9);
      u32(0);
    } else if (v is List<String>) {
      byte(9);
      u32(v.length);
      for (final s in v) {
        str(s);
      }
    } else {
      throw StateError('Tipo legacy no soportado para ${v.runtimeType}');
    }
  }

  void field(int key, dynamic v) {
    byte(key);
    value(v);
  }

  // 16 campos igual que el adapter original.
  byte(16);
  field(0, 'singleton');
  field(1, 'Ada');
  field(2, 6);
  field(3, false);
  field(4, 1); // AppThemeMode.light
  field(5, <String>['dark']);
  field(6, 'Europe/Madrid');
  field(7, true);
  field(8, true);
  field(9, false);
  field(10, false);
  field(11, false);
  field(12, true);
  field(13, <String>[]);
  field(14, null);
  // customBadgeConfigs vacío: lista generica
  byte(15);
  byte(10);
  u32(0);

  return builder.toBytes();
}

void main() {
  late Directory tempDir;
  late Box<UserSettings> box;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('slate_hive_test');
    Hive.init(tempDir.path);
    Hive.registerAdapter(UserSettingsAdapter());
  });

  setUp(() async {
    box = await Hive.openBox<UserSettings>('settings_test');
  });

  tearDown(() async {
    await box.close();
    await Hive.deleteBoxFromDisk('settings_test');
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  group('UserSettingsAdapter', () {
    test('roundtrip preserva todos los campos', () async {
      const original = UserSettings(
        id: 'singleton',
        userName: 'Ada',
        dayResetHour: 6,
        notificationsEnabled: false,
        themeMode: AppThemeMode.light,
        unlockedThemeIds: ['dark', 'neon'],
        timezone: 'Europe/Madrid',
        autoDetectTimezone: true,
        locationPermissionGranted: true,
        useAINotifications: true,
        notificationSound: false,
        notificationVibration: true,
        notificationBadge: false,
        notificationImagePaths: ['/img/a.png', '/img/b.png'],
        notificationTextContext: 'contexto de prueba',
        customBadgeConfigs: [
          CustomBadgeConfig(
            badgeType: 'streak30',
            customName: 'Racha 30',
            iconName: 'fire',
            daysRequired: 30,
          ),
          CustomBadgeConfig(
            badgeType: 'custom90',
            customName: 'Noventa',
            iconName: 'star',
            daysRequired: 90,
          ),
        ],
        notificationLeadTimeMinutes: 20,
        dailyReminderEnabled: false,
        dailyReminderHour1: 8,
        dailyReminderHour2: 21,
      );

      await box.put('settings', original);
      final restored = box.get('settings');

      expect(restored, isNotNull);
      expect(restored, equals(original));
      expect(restored!.customBadgeConfigs, hasLength(2));
      expect(restored.customBadgeConfigs[1].daysRequired, 90);
      expect(restored.notificationLeadTimeMinutes, 20);
      expect(restored.dailyReminderEnabled, isFalse);
      expect(restored.dailyReminderHour1, 8);
      expect(restored.dailyReminderHour2, 21);
    });

    test('roundtrip con valores por defecto no lanza errores', () async {
      const original = UserSettings();

      await box.put('settings', original);
      final restored = box.get('settings');

      expect(restored, isNotNull);
      expect(restored, equals(original));
      expect(restored!.customBadgeConfigs, isEmpty);
      expect(restored.notificationLeadTimeMinutes, 0);
      expect(restored.dailyReminderEnabled, isTrue);
      expect(restored.dailyReminderHour1, 10);
      expect(restored.dailyReminderHour2, 19);
    });

    test(
        'migración: un registro ANTIGUO (16 campos) se lee aplicando los defaults nuevos',
        () {
      final adapter = UserSettingsAdapter();
      final legacy = adapter.read(_LegacyBytesReader(legacy16FieldBytes()));

      // Los 16 campos antiguos se conservan.
      expect(legacy.id, 'singleton');
      expect(legacy.userName, 'Ada');
      expect(legacy.dayResetHour, 6);
      expect(legacy.notificationsEnabled, isFalse);
      expect(legacy.themeMode, AppThemeMode.light);
      expect(legacy.unlockedThemeIds, ['dark']);
      expect(legacy.timezone, 'Europe/Madrid');
      expect(legacy.autoDetectTimezone, isTrue);
      expect(legacy.locationPermissionGranted, isTrue);
      expect(legacy.useAINotifications, isFalse);
      expect(legacy.notificationSound, isFalse);
      expect(legacy.notificationVibration, isFalse);
      expect(legacy.notificationBadge, isTrue);
      expect(legacy.customBadgeConfigs, isEmpty);

      // Los campos NUEVOS (añadidos después) toman sus defaults.
      expect(legacy.notificationLeadTimeMinutes, 0);
      expect(legacy.dailyReminderEnabled, isTrue);
      expect(legacy.dailyReminderHour1, 10);
      expect(legacy.dailyReminderHour2, 19);
    });
  });
}
