import 'package:flutter_test/flutter_test.dart';

import 'package:slate_app/domain/entities/streak.dart';
import 'package:slate_app/presentation/screens/progress/widgets/streak_display.dart';

import '../../../helpers/pump_with_slate_theme.dart';

final _now = DateTime(2026, 3, 10, 12, 0);

void main() {
  group('StreakDisplay - render básico', () {
    testWidgets('racha en 0 (caso borde): sin crashear y con "0 días seguidos"',
        (tester) async {
      await pumpWithSlateTheme(
        tester,
        StreakDisplay(
          streak: Streak(id: 'streak', currentStreak: 0, longestStreak: 0, updatedAt: _now),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('0 días seguidos'), findsOneWidget);
      expect(find.text('Tu racha más larga: 0 días'), findsOneWidget);
    });

    testWidgets('racha de 1 día: concordancia singular correcta', (tester) async {
      await pumpWithSlateTheme(
        tester,
        StreakDisplay(
          streak: Streak(id: 'streak', currentStreak: 1, longestStreak: 4, updatedAt: _now),
        ),
      );

      expect(find.text('1 día seguido'), findsOneWidget);
      expect(find.text('1 día seguidos'), findsNothing,
          reason: 'concordancia: "seguido" también debe ir en singular con 1 día');
    });

    testWidgets('racha con datos reales (varios días, racha más larga distinta)',
        (tester) async {
      await pumpWithSlateTheme(
        tester,
        StreakDisplay(
          streak: Streak(id: 'streak', currentStreak: 7, longestStreak: 21, updatedAt: _now),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('7 días seguidos'), findsOneWidget);
      expect(find.text('Tu racha más larga: 21 días'), findsOneWidget);
    });
  });
}
