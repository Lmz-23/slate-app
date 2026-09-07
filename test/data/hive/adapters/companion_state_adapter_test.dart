import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:slate_app/data/hive/adapters/companion_state_adapter.dart';
import 'package:slate_app/domain/entities/companion_state.dart';

void main() {
  late Directory tempDir;
  late Box<CompanionState> box;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('slate_companion_test');
    Hive.init(tempDir.path);
    Hive.registerAdapter(CompanionStateAdapter());
  });

  setUp(() async {
    box = await Hive.openBox<CompanionState>('companion_test');
  });

  tearDown(() async {
    await box.close();
    await Hive.deleteBoxFromDisk('companion_test');
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  group('CompanionStateAdapter (typeId 5)', () {
    test('roundtrip preserva los campos de la quest (F3)', () async {
      final original = CompanionState(
        questClaimedOn: '2026-8-10',
        questVisibleOn: '2026-8-10',
        questVisibleDecision: true,
        updatedAt: DateTime(2026, 8, 10, 9, 30),
      );

      await box.put('main_companion', original);
      final restored = box.get('main_companion');

      expect(restored, isNotNull);
      expect(restored, equals(original));
      expect(restored!.questClaimedOn, '2026-8-10');
      expect(restored.questVisibleOn, '2026-8-10');
      expect(restored.questVisibleDecision, isTrue);
      expect(restored.updatedAt, DateTime(2026, 8, 10, 9, 30));
    });

    test('roundtrip con decisión de visibilidad FALSE y sin claim', () async {
      final original = CompanionState(
        questVisibleOn: '2026-8-10',
        questVisibleDecision: false,
        updatedAt: DateTime(2026, 8, 10, 7, 0),
      );

      await box.put('main_companion', original);
      final restored = box.get('main_companion');

      expect(restored, equals(original));
      expect(restored!.questClaimedOn, isNull);
      expect(restored.questVisibleDecision, isFalse);
    });

    test('valores por defecto cuando faltan campos (campos null)', () async {
      final original = CompanionState(updatedAt: DateTime(2026, 8, 10));

      await box.put('main_companion', original);
      final restored = box.get('main_companion');

      expect(restored, equals(original));
      expect(restored!.id, 'main_companion');
      expect(restored.questClaimedOn, isNull);
      expect(restored.questVisibleOn, isNull);
      expect(restored.questVisibleDecision, isFalse);
    });
  });
}