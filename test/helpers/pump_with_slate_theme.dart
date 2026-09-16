import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slate_app/core/theme/app_theme.dart';

/// Envuelve [widget] en un [MaterialApp] con el tema real de la app
/// ([AppTheme.darkTheme] por defecto, o [AppTheme.lightTheme] si
/// `brightness: Brightness.light`) y lo bombea.
///
/// Úsalo en tests de widget que dependan de `SlateColors.of(context)` /
/// `context.slate`, en vez de un `MaterialApp` desnudo: sin la extensión
/// [SlateColors] registrada en el tema, `SlateColors.of` cae en su
/// fallback (`SlateColors.dark`), lo que puede ocultar bugs de theming en
/// vez de detectarlos.
///
/// Ejemplo:
/// ```dart
/// await pumpWithSlateTheme(tester, const TaskTile(task: myTask));
/// ```
Future<void> pumpWithSlateTheme(
  WidgetTester tester,
  Widget widget, {
  Brightness brightness = Brightness.dark,
}) {
  final theme =
      brightness == Brightness.light ? AppTheme.lightTheme : AppTheme.darkTheme;

  return tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(body: widget),
    ),
  );
}
