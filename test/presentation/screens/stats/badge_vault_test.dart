import 'dart:io';

import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:slate_app/application/providers/streak_provider.dart';
import 'package:slate_app/data/hive/adapters/streak_adapter.dart';
import 'package:slate_app/data/hive/adapters/badge_adapter.dart';
import 'package:slate_app/data/hive/boxes/streaks_box.dart';
import 'package:slate_app/data/hive/boxes/badges_box.dart';
import 'package:slate_app/domain/entities/badge.dart';
import 'package:slate_app/domain/entities/task.dart';
import 'package:slate_app/domain/enums/badge_type.dart';
import 'package:slate_app/presentation/screens/stats/widgets/badge_vault.dart';

/// Réplica de cómo StatsScreen consume el estado: observa `badgesProvider` y
/// pasa la lista a `BadgeVault`. Permite verificar que el widget se reconstruye
/// cuando el provider cambia su estado.
class _BadgeVaultConsumer extends ConsumerWidget {
  const _BadgeVaultConsumer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badges = ref.watch(badgesProvider);
    return BadgeVault(badges: badges);
  }
}

Task _task(String id, DateTime scheduledDate, {bool isCompleted = true}) {
  return Task(
    id: id,
    title: 'Tarea $id',
    scheduledDate: scheduledDate,
    isCompleted: isCompleted,
    createdAt: scheduledDate,
    completedAt: isCompleted ? scheduledDate : null,
  );
}

DateTime _d(int y, int m, int d) => DateTime(y, m, d);
DateTime _now(int y, int m, int d) => DateTime(y, m, d, 12);

Badge _badge(BadgeType type, {String? id}) {
  return Badge(
    id: id ?? 'b-${type.name}',
    type: type,
    name: type.name,
    iconName: type.iconName,
    unlockedAt: DateTime(2026, 1, 14),
    isDisplayed: true,
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
  group('BadgeVault - render directo', () {
    testWidgets('muestra la insignia desbloqueada y las demás como ???', (tester) async {
      await _pumpInScrollView(tester, const BadgeVault(badges: []));

      // Sin insignias: todos los tipos aparecen bloqueados.
      expect(find.text('Vitrina de insignias'), findsOneWidget);
      expect(find.text('???'), findsNWidgets(BadgeType.values.length));
      expect(find.text('Rango E · Nivel I'), findsNothing);
    });

    testWidgets('una insignia desbloqueada muestra su rango SL y quita su ???', (tester) async {
      await _pumpInScrollView(
        tester,
        BadgeVault(badges: [_badge(BadgeType.streak3)]),
      );

      expect(find.text('Rango E · Nivel I'), findsOneWidget);
      expect(find.text('???'), findsNWidgets(BadgeType.values.length - 1));

      // El apodo y el umbral de la insignia desbloqueada se siguen mostrando.
      expect(find.text('El Despertar · 3 días'), findsOneWidget);
    });

    testWidgets('varias insignias desbloqueadas se muestran todas', (tester) async {
      await _pumpInScrollView(
        tester,
        BadgeVault(badges: [
          _badge(BadgeType.streak3),
          _badge(BadgeType.streak7),
          _badge(BadgeType.streak14),
        ]),
      );

      expect(find.text('Rango E · Nivel I'), findsOneWidget);
      expect(find.text('Rango E · Nivel II'), findsOneWidget);
      expect(find.text('Rango D · Nivel I'), findsOneWidget);
      expect(find.text('???'), findsNWidgets(BadgeType.values.length - 3));
    });
  });

  group('BadgeVault - identidad Slate System (fuente única)', () {
    testWidgets('siempre muestra rangos/niveles y apodos', (tester) async {
      await _pumpInScrollView(
        tester,
        BadgeVault(badges: [_badge(BadgeType.streak14)]),
      );

      expect(find.text('Rango D · Nivel I'), findsOneWidget);
      expect(find.text('Guía del acero · 14 días'), findsOneWidget);
      expect(find.text('Quincena'), findsNothing,
          reason: 'el nombre canónico ya no existe en la identidad única');
    });

    testWidgets('los hitos de racha con umbral siguen en la vitrina',
        (tester) async {
      // Los 9 hitos E→S se CONSERVAN: aquí se verifica el escalón más alto.
      await _pumpInScrollView(
        tester,
        BadgeVault(badges: [_badge(BadgeType.streak365)]),
      );

      expect(find.text('Nivel Nacional'), findsOneWidget);
      expect(find.text('Leyenda · 365 días'), findsOneWidget);
    });
  });

  group('BadgeVault - reflejo al instante vía badgesProvider', () {
    late Directory tempDir;
    late StreaksBox streaksBox;
    late BadgesBox badgesBox;
    late ProviderContainer container;

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('slate_badge_vault_test');
      Hive.init(tempDir.path);
      Hive.registerAdapter(StreakAdapter());
      Hive.registerAdapter(BadgeAdapter());
    });

    setUp(() async {
      streaksBox = StreaksBox();
      await streaksBox.init();
      badgesBox = BadgesBox();
      await badgesBox.init();

      container = ProviderContainer(
        overrides: [
          streaksBoxProvider.overrideWithValue(streaksBox),
          badgesBoxProvider.overrideWithValue(badgesBox),
        ],
      );
      addTearDown(container.dispose);
    });

    tearDown(() async {
      await Hive.close();
      await Hive.deleteBoxFromDisk('streaks');
      await Hive.deleteBoxFromDisk('badges');
    });

    tearDownAll(() async {
      await tempDir.delete(recursive: true);
    });

    testWidgets('la insignia desbloqueada aparece sin reiniciar la app', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: _BadgeVaultConsumer()),
            ),
          ),
        ),
      );
      expect(find.text('Rango E · Nivel I'), findsNothing);

      // Flujo real de desbloqueo: completar 3 tareas → recalculate (racha 3).
      // La escritura en Hive es I/O real, por lo que se ejecuta fuera del
      // reloj falso de testWidgets (runAsync).
      await tester.runAsync(() async {
        await container.read(streakProvider.notifier).recalculate(
              tasks: [
                _task('a', _d(2026, 1, 12)),
                _task('b', _d(2026, 1, 13)),
                _task('c', _d(2026, 1, 14)),
              ],
              now: _now(2026, 1, 14),
            );
      });

      // Riverpod notifica el nuevo estado de badgesProvider; el widget se
      // reconstruye y BadgeVault muestra la insignia inmediatamente.
      await tester.pump();

      expect(find.text('Rango E · Nivel I'), findsOneWidget);
      expect(find.text('???'), findsNWidgets(BadgeType.values.length - 1));
    });

    testWidgets('desmarcar tareas no retira la insignia de la vitrina', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: _BadgeVaultConsumer()),
            ),
          ),
        ),
      );

      await tester.runAsync(() async {
        await container.read(streakProvider.notifier).recalculate(
              tasks: [
                _task('a', _d(2026, 1, 12)),
                _task('b', _d(2026, 1, 13)),
                _task('c', _d(2026, 1, 14)),
              ],
              now: _now(2026, 1, 14),
            );
      });
      await tester.pump();
      expect(find.text('Rango E · Nivel I'), findsOneWidget);

      // Racha baja a 0: la insignia sigue visible.
      await tester.runAsync(() async {
        await container.read(streakProvider.notifier).recalculate(
              tasks: [
                _task('a', _d(2026, 1, 12), isCompleted: false),
                _task('b', _d(2026, 1, 13), isCompleted: false),
                _task('c', _d(2026, 1, 14), isCompleted: false),
              ],
              now: _now(2026, 1, 14),
            );
      });
      await tester.pump();

      expect(container.read(streakProvider).currentStreak, 0);
      expect(find.text('Rango E · Nivel I'), findsOneWidget);
      expect(find.text('???'), findsNWidgets(BadgeType.values.length - 1));
    });
  });
}