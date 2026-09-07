import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:slate_app/application/providers/player_provider.dart';
import 'package:slate_app/application/providers/quest_provider.dart';
import 'package:slate_app/data/hive/boxes/companion_state_box.dart';
import 'package:slate_app/data/hive/boxes/player_progress_box.dart';
import 'package:slate_app/data/repositories/companion_state_repository_impl.dart';
import 'package:slate_app/domain/entities/companion_state.dart';
import 'package:slate_app/domain/entities/player_profile.dart';
import 'package:slate_app/domain/entities/task.dart';
import 'package:slate_app/presentation/screens/home/widgets/quest_card.dart';
import 'package:slate_app/presentation/widgets/common/slate_card.dart';

/// Cajas en memoria: misma API, sin I/O real de Hive (los `testWidgets` corren
/// en zona FakeAsync y no deben colgarse con I/O de archivos).
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

/// Caja con estado inicial prefijado (la questProvider la actualiza luego).
class _QueuedCompanionBox extends CompanionStateBox {
  _QueuedCompanionBox(this._initial);
  CompanionState _initial;

  @override
  Future<void> init() async {}

  @override
  CompanionState getState() => _initial;

  @override
  Future<void> updateState(CompanionState state) async {
    _initial = state;
  }
}

Task _task(String id, DateTime day, {bool done = false}) => Task(
      id: id,
      title: 'Tarea $id',
      scheduledDate: day,
      isCompleted: done,
      completedAt: done ? day.add(const Duration(hours: 1)) : null,
      createdAt: day,
    );

/// Construye un contenedor con la QuestCard y dependencias controladas.
ProviderContainer _container({
  required List<Task> tasks,
  CompanionState? companion,
  DateTime? now,
}) {
  final playerBox = _InMemoryPlayerBox();
  final companionBox = _QueuedCompanionBox(
    companion ?? CompanionState(updatedAt: DateTime(2026, 1, 15)),
  );
  return ProviderContainer(
    overrides: [
      companionStateBoxProvider.overrideWithValue(companionBox),
      playerProgressBoxProvider.overrideWithValue(playerBox),
      questProvider.overrideWith((ref) {
        return QuestNotifier(
          repository: CompanionStateRepositoryImpl(companionBox),
          // Misma instancia que observa la UI vía `playerProvider`: en
          // producción questProvider usa `ref.watch(playerProvider.notifier)`,
          // por lo que el +25 del claim se refleja en el notifier que lee el
          // test. Antes se creaba un PlayerNotifier aparte y el claim actualizaba
          // un estado que `container.read(playerProvider)` no veía.
          playerNotifier: ref.read(playerProvider.notifier),
          readTasks: () => tasks,
          readNow: () => now ?? DateTime(2026, 1, 15, 12, 0),
        );
      }),
    ],
  );
}

Future<void> _pumpCard(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: QuestCard()),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('QuestCard (F3, decisión C)', () {
    testWidgets('la quest invisible hoy NO pinta la tarjeta', (tester) async {
      final container = _container(tasks: const []);
      addTearDown(container.dispose);

      await _pumpCard(tester, container);

      expect(find.byType(QuestCard), findsOneWidget);
      expect(find.byType(SlateCard), findsNothing,
          reason: 'sin ≥3 tareas la quest se reduce a SizedBox.shrink');
      expect(find.textContaining('Daily Quest'), findsNothing);
    });

    testWidgets('visible pero en progreso: muestra el conteo y "En progreso"',
        (tester) async {
      final container = _container(
        tasks: [
          _task('a', DateTime(2026, 1, 15)),
          _task('b', DateTime(2026, 1, 15)),
          _task('c', DateTime(2026, 1, 15)),
        ],
      );
      addTearDown(container.dispose);

      await _pumpCard(tester, container);

      expect(find.textContaining('Daily Quest'), findsOneWidget);
      expect(find.text('0 / 3 completadas'), findsOneWidget);
      expect(find.text('En progreso'), findsOneWidget);
      expect(find.textContaining('Reclamar'), findsNothing,
          reason: 'con 0 completadas no hay botón de reclamar');
    });

    testWidgets('con 3 completadas HOY muestra el botón "Reclamar +25 XP"',
        (tester) async {
      final container = _container(
        tasks: [
          _task('a', DateTime(2026, 1, 15), done: true),
          _task('b', DateTime(2026, 1, 15), done: true),
          _task('c', DateTime(2026, 1, 15), done: true),
        ],
      );
      addTearDown(container.dispose);

      await _pumpCard(tester, container);

      expect(find.text('3 / 3 completadas'), findsOneWidget);
      expect(find.text('▶ Reclamar +25 XP'), findsOneWidget);
    });

    testWidgets('al pulsar Reclamar da +25 XP y muestra "Reclamada"',
        (tester) async {
      final container = _container(
        tasks: [
          _task('a', DateTime(2026, 1, 15), done: true),
          _task('b', DateTime(2026, 1, 15), done: true),
          _task('c', DateTime(2026, 1, 15), done: true),
        ],
      );
      addTearDown(container.dispose);

      await _pumpCard(tester, container);
      expect(find.text('▶ Reclamar +25 XP'), findsOneWidget);

      final xpBefore = container.read(playerProvider).totalXp;
      await tester.tap(find.text('▶ Reclamar +25 XP'));
      await tester.pumpAndSettle();

      expect(container.read(playerProvider).totalXp, xpBefore + 25);
      expect(find.text('Reclamada'), findsOneWidget);
      expect(find.textContaining('Reclamar'), findsNothing,
          reason: 'reclamable 1 vez por día');
    });

    testWidgets('nivel nuevo por el +25: muestra el SnackBar de nivel UNA vez',
        (tester) async {
      final container = _container(
        tasks: [
          _task('a', DateTime(2026, 1, 15), done: true),
          _task('b', DateTime(2026, 1, 15), done: true),
          _task('c', DateTime(2026, 1, 15), done: true),
        ],
      );
      addTearDown(container.dispose);

      // 90 XP + 25 = 115 → nivel 2: sube el nivel y muestra el SnackBar.
      await tester.runAsync(() async {
        for (var i = 0; i < 45; i++) {
          await container.read(playerProvider.notifier).addSubtaskXp();
        }
      });
      expect(container.read(playerProvider).totalXp, 90);

      await _pumpCard(tester, container);
      await tester.tap(find.text('▶ Reclamar +25 XP'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Nivel subió'), findsOneWidget);
      expect(container.read(playerProvider).level, 2);
    });
  });
}