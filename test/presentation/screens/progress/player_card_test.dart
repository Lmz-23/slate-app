import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:slate_app/application/providers/player_provider.dart';
import 'package:slate_app/application/services/player_xp_calculator.dart';
import 'package:slate_app/data/hive/boxes/player_progress_box.dart';
import 'package:slate_app/domain/entities/player_profile.dart';
import 'package:slate_app/domain/enums/player_rank.dart';
import 'package:slate_app/domain/enums/task_priority.dart';
import 'package:slate_app/presentation/screens/stats/widgets/player_card.dart';

/// Réplica de cómo StatsScreen consume el estado: observa `playerProvider` y
/// pasa el perfil a [PlayerCard]. Permite verificar el reflejo al instante.
class _PlayerCardConsumer extends ConsumerWidget {
  const _PlayerCardConsumer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(playerProvider);
    return PlayerCard(profile: profile);
  }
}

/// `PlayerProgressBox` en memoria: misma API, sin I/O real de Hive. Esto evita
/// que `testWidgets` (zona FakeAsync) se cuelgue con el I/O de archivos.
class _InMemoryPlayerBox extends PlayerProgressBox {
  PlayerProfile? _profile;

  @override
  Future<void> init() async {}

  @override
  PlayerProfile getProfile() {
    _profile ??= PlayerProfile(
      id: 'main_player',
      totalXp: 0,
      level: 1,
      shownLevelUps: const {},
      updatedAt: DateTime(2026, 1, 15, 10, 0),
    );
    return _profile!;
  }

  @override
  Future<void> updateProfile(PlayerProfile profile) async {
    _profile = profile;
  }
}

PlayerProfile _profile({
  int totalXp = 0,
  int level = 1,
  Set<int> shownLevelUps = const {},
}) {
  return PlayerProfile(
    id: 'main_player',
    totalXp: totalXp,
    level: level,
    shownLevelUps: shownLevelUps,
    updatedAt: DateTime(2026, 1, 15, 10, 0),
  );
}

/// Pinta [child] dentro de la superficie de test sin overflow vertical.
Future<void> _pumpInScrollView(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    ),
  );
}

void main() {
  group('PlayerCard - render directo', () {
    testWidgets('muestra nivel, rango y barra de XP', (tester) async {
      await _pumpInScrollView(
        tester,
        PlayerCard(profile: _profile(totalXp: 250, level: 2)),
      );

      expect(find.text('◆ JUGADOR'), findsOneWidget);
      expect(find.text('Nivel 2'), findsOneWidget);
      expect(find.text('Rango E'), findsOneWidget,
          reason: 'nivel 1-9 → rango E');
      expect(find.text('150 / 300 XP'), findsOneWidget,
          reason: 'XP dentro del nivel (250-100) / tramo (400-100)');
    });

    testWidgets('rango E→S por tramos: nivel 1 → E', (tester) async {
      await _pumpInScrollView(tester, PlayerCard(profile: _profile()));

      expect(find.text('Nivel 1'), findsOneWidget);
      expect(find.text('Rango E'), findsOneWidget);
      expect(find.text('0 / 100 XP'), findsOneWidget);
    });

    testWidgets('rango S para niveles altos (70+)', (tester) async {
      await _pumpInScrollView(
        tester,
        PlayerCard(profile: _profile(totalXp: 100 * 75 * 75, level: 75)),
      );
      expect(find.text('Rango S'), findsOneWidget);
    });

    test('progressToNextLevel alimenta la barra (valor esperado)', () {
      expect(
        PlayerXpCalculator.progressToNextLevel(250, 2),
        closeTo(150 / 300, 0.001),
      );
      expect(PlayerXpCalculator.rankForLevel(2), PlayerRank.e);
      expect(PlayerXpCalculator.rankForLevel(12), PlayerRank.d,
          reason: 'nivel 10-19 → rango D');
    });
  });

  group('PlayerCard - reflejo al instante vía playerProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          // Solo la caja: playerRepositoryProvider y playerProvider se
          // construyen sobre ella de forma automática.
          playerProgressBoxProvider.overrideWithValue(_InMemoryPlayerBox()),
        ],
      );
      addTearDown(container.dispose);
    });

    testWidgets('la tarjeta refleja el XP/nivel al instante sin reiniciar',
        (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: _PlayerCardConsumer()),
            ),
          ),
        ),
      );
      expect(find.text('Nivel 1'), findsOneWidget);
      expect(find.text('Rango E'), findsOneWidget);

      // Flujo real: completar 5 tareas altas (5×20 = 100 XP → nivel 2).
      await tester.runAsync(() async {
        for (var i = 0; i < 5; i++) {
          await container
              .read(playerProvider.notifier)
              .addTaskXp(TaskPriority.high);
        }
      });
      await tester.pump();

      expect(find.text('Nivel 2'), findsOneWidget);
      expect(find.text('Rango E'), findsOneWidget,
          reason: 'nivel 2 (1-9) → rango E');
    });

    testWidgets('desmarcar tareas no baja el nivel en la tarjeta',
        (tester) async {
      await tester.runAsync(() async {
        for (var i = 0; i < 5; i++) {
          await container
              .read(playerProvider.notifier)
              .addTaskXp(TaskPriority.high);
        }
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: _PlayerCardConsumer()),
            ),
          ),
        ),
      );
      expect(find.text('Nivel 2'), findsOneWidget);

      // Desmarcar todo: XP baja a 0 pero el nivel se mantiene.
      await tester.runAsync(() async {
        for (var i = 0; i < 5; i++) {
          await container
              .read(playerProvider.notifier)
              .removeTaskXp(TaskPriority.high);
        }
      });
      await tester.pump();

      expect(find.text('Nivel 2'), findsOneWidget);
      expect(find.text('Rango E'), findsOneWidget,
          reason: 'el nivel se mantiene, rango E para niveles 1-9');
    });
  });
}