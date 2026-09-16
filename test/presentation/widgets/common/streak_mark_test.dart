import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:slate_app/core/theme/app_theme.dart';
import 'package:slate_app/core/theme/slate_colors.dart';
import 'package:slate_app/presentation/widgets/common/streak_mark.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

Container _rotatedContainer(WidgetTester tester) {
  return tester.widget<Container>(
    find.descendant(of: find.byType(Transform), matching: find.byType(Container)),
  );
}

void main() {
  group('StreakMark - tamaños', () {
    testWidgets('tamaño small (por defecto) mide 9x9', (tester) async {
      await _pump(tester, const StreakMark());
      final container = _rotatedContainer(tester);
      expect(container.constraints?.maxWidth, 9.0);
      expect(container.constraints?.maxHeight, 9.0);
    });

    testWidgets('tamaño large mide 20x20', (tester) async {
      await _pump(tester, const StreakMark(size: StreakMarkSize.large));
      final container = _rotatedContainer(tester);
      expect(container.constraints?.maxWidth, 20.0);
      expect(container.constraints?.maxHeight, 20.0);
    });
  });

  group('StreakMark - color', () {
    testWidgets('siempre usa el color "accent" del tema, en ambos tamaños', (tester) async {
      await _pump(tester, const StreakMark());
      final context = tester.element(find.byType(StreakMark));
      final container = _rotatedContainer(tester);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, SlateColors.of(context).accent);
    });
  });
}
