import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:slate_app/data/backup/backup_codec.dart';
import 'package:slate_app/domain/entities/companion_state.dart';
import 'package:slate_app/domain/entities/player_profile.dart';
import 'package:slate_app/domain/entities/task.dart';
import 'package:slate_app/domain/entities/user_settings.dart';
import 'package:slate_app/domain/enums/recurrence_type.dart';

void main() {
  PlayerProfile samplePlayerFixed() => PlayerProfile(
        id: 'main_player',
        totalXp: 327,
        level: 3,
        shownLevelUps: const {2, 3},
        updatedAt: DateTime(2026, 8, 10, 11, 30),
      );

  CompanionState sampleCompanion() => CompanionState(
        id: 'main_companion',
        questClaimedOn: '2026-8-10',
        questVisibleOn: '2026-8-10',
        questVisibleDecision: true,
        updatedAt: DateTime(2026, 8, 10, 11, 30),
      );

  String encodeWith({
    PlayerProfile? player,
    CompanionState? companion,
    List<Task> tasks = const [],
  }) {
    return BackupCodec.encode(
      tasks: tasks,
      categories: const [],
      streaks: const [],
      badges: const [],
      userSettings: const UserSettings(),
      appMeta: const {},
      thematicTextCache: const {},
      playerProgress: player,
      companionState: companion,
      exportedAt: DateTime(2026, 8, 10, 12),
    );
  }

  group('BackupCodec F4 - PlayerProfile y CompanionState (secciones nuevas)',
      () {
    test('encode incluye playerProgress y companionState completos', () {
      final decoded = jsonDecode(
              encodeWith(player: samplePlayerFixed(), companion: sampleCompanion()))
          as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>;

      final player = data['playerProgress'] as Map<String, dynamic>;
      expect(player['id'], 'main_player');
      expect(player['totalXp'], 327);
      expect(player['level'], 3);
      expect(player['shownLevelUps'], [2, 3]);
      expect(player['updatedAt'], '2026-08-10T11:30:00.000');

      final companion = data['companionState'] as Map<String, dynamic>;
      expect(companion['id'], 'main_companion');
      expect(companion['questClaimedOn'], '2026-8-10');
      expect(companion['questVisibleOn'], '2026-8-10');
      expect(companion['questVisibleDecision'], isTrue);
      expect(companion['updatedAt'], '2026-08-10T11:30:00.000');
    });

    test('roundtrip preserva PlayerProfile (incl. shownLevelUps) y '
        'CompanionState (incl. campos de quest)', () {
      final decoded = BackupCodec.decode(encodeWith(
        player: samplePlayerFixed(),
        companion: sampleCompanion(),
      ));

      expect(decoded.playerProgress, samplePlayerFixed(),
          reason: 'Equatable compara totalXp/level/shownLevelUps/updatedAt');
      expect(decoded.playerProgress!.shownLevelUps, {2, 3});
      expect(decoded.companionState, sampleCompanion());
      expect(decoded.companionState!.questClaimedOn, '2026-8-10');
      expect(decoded.companionState!.questVisibleDecision, isTrue);
    });

    test('roundtrip de un perfil con quest NO reclamada y decisión oculta', () {
      final decoded = BackupCodec.decode(encodeWith(
        player: samplePlayerFixed(),
        companion: CompanionState(
          id: 'main_companion',
          questClaimedOn: null,
          questVisibleOn: '2026-8-9',
          questVisibleDecision: false,
          updatedAt: DateTime(2026, 8, 9, 22),
        ),
      ));

      expect(decoded.companionState!.questClaimedOn, isNull);
      expect(decoded.companionState!.questVisibleDecision, isFalse);
      expect(decoded.companionState!.questVisibleOn, '2026-8-9');
    });

    test('un backup sin las secciones F4 (compatibilidad hacia atrás) se '
        'importa con valores null', () {
      final decoded = BackupCodec.decode(encodeWith());

      expect(decoded.playerProgress, isNull);
      expect(decoded.companionState, isNull);
    });
  });

  group('BackupCodec F4 - tareas con subtareas y recurrencia mensual', () {
    test('roundtrip conserva isSubtask y subtaskXpGranted', () {
      final task = Task(
        id: 't-sub',
        title: 'Detalle',
        scheduledDate: DateTime(2026, 8, 10),
        createdAt: DateTime(2026, 8, 10),
        parentTaskId: 't-main',
        isSubtask: true,
        subtaskXpGranted: true,
      );
      final decoded = BackupCodec.decode(encodeWith(tasks: [task]));

      expect(decoded.tasks.single.isSubtask, isTrue);
      expect(decoded.tasks.single.subtaskXpGranted, isTrue);
      expect(decoded.tasks.single, task);
    });

    test('un backup de tarea sin campos de subtarea cae a false (v1 anterior)',
        () {
      // Manually craft a task JSON without the F4 boolean fields.
      final base = jsonDecode(encodeWith()) as Map<String, dynamic>;
      (base['data'] as Map<String, dynamic>)['tasks'] = [
        {
          'id': 't-old',
          'title': 'Antigua',
          'scheduledDate': '2026-01-01T00:00:00.000',
          'createdAt': '2026-01-01T00:00:00.000',
          'recurrence': 'monthly',
        },
      ];
      final decoded = BackupCodec.decode(jsonEncode(base));

      expect(decoded.tasks.single.isSubtask, isFalse);
      expect(decoded.tasks.single.subtaskXpGranted, isFalse);
      expect(decoded.tasks.single.recurrence, RecurrenceType.monthly,
          reason: 'el nombre del enum mensual es estable en los backups');
    });
  });

  group('BackupCodec F4 - validación de las secciones nuevas', () {
    test('rechaza playerProgress con tipo incorrecto', () {
      final bad = jsonDecode(encodeWith(player: samplePlayerFixed()))
          as Map<String, dynamic>;
      (bad['data'] as Map<String, dynamic>)['playerProgress'] = 'no-objeto';
      expect(
        () => BackupCodec.decode(jsonEncode(bad)),
        throwsA(isA<BackupException>()
            .having((e) => e.message, 'message', contains('playerProgress'))),
      );
    });

    test('rechaza companionState con tipo incorrecto', () {
      final bad = jsonDecode(encodeWith(companion: sampleCompanion()))
          as Map<String, dynamic>;
      (bad['data'] as Map<String, dynamic>)['companionState'] = 42;
      expect(
        () => BackupCodec.decode(jsonEncode(bad)),
        throwsA(isA<BackupException>()
            .having((e) => e.message, 'message', contains('companionState'))),
      );
    });

    test('rechaza playerProgress con entradas rotas (sin updatedAt)', () {
      final bad = jsonDecode(encodeWith(player: samplePlayerFixed()))
          as Map<String, dynamic>;
      (bad['data'] as Map<String, dynamic>)['playerProgress'] = {
        'id': 'main_player',
        'totalXp': 10,
      };
      expect(
        () => BackupCodec.decode(jsonEncode(bad)),
        throwsA(isA<BackupException>()
            .having((e) => e.message, 'message', contains('inválidas'))),
      );
    });

    test('rechaza companionState con updatedAt inválido', () {
      final bad = jsonDecode(encodeWith(companion: sampleCompanion()))
          as Map<String, dynamic>;
      (bad['data'] as Map<String, dynamic>)['companionState'] = {
        'id': 'main_companion',
        'questVisibleDecision': true,
        'updatedAt': 'no-es-fecha',
      };
      expect(
        () => BackupCodec.decode(jsonEncode(bad)),
        throwsA(isA<BackupException>()
            .having((e) => e.message, 'message', contains('inválidas'))),
      );
    });
  });
}