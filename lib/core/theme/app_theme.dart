import 'package:flutter/material.dart';

import 'slate_colors.dart';
import 'slate_shapes.dart';
import 'slate_typography.dart';

/// Fábrica única de [ThemeData] para el nuevo sistema visual de slate-app.
///
/// Antes de esta refactorización, `lightTheme` y `darkTheme` se construían
/// por separado a mano, lo que permitía que ambos temas divergieran sin
/// darse cuenta (causa raíz documentada en RG11 de
/// docs/architecture/rediseno-identidad-visual.md — Decisión A1). Ahora
/// ambos invocan la misma función privada [_build], variando solo los
/// tokens ([SlateColors], [SlateShapes]) y el [Brightness].
class AppTheme {
  const AppTheme._();

  static final ThemeData lightTheme = _build(
    colors: SlateColors.light,
    shapes: SlateShapes.light,
    typography: SlateTypography.standard,
    brightness: Brightness.light,
  );

  static final ThemeData darkTheme = _build(
    colors: SlateColors.dark,
    shapes: SlateShapes.dark,
    typography: SlateTypography.standard,
    brightness: Brightness.dark,
  );

  static ThemeData _build({
    required SlateColors colors,
    required SlateShapes shapes,
    required SlateTypography typography,
    required Brightness brightness,
  }) {
    final textTheme = typography.toTextTheme(
      textPrimary: colors.textPrimary,
      textSecondary: colors.textSecondary,
      textTertiary: colors.textTertiary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: colors.background,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: colors.accent,
        onPrimary: colors.onAccent,
        secondary: colors.accent,
        onSecondary: colors.onAccent,
        error: colors.danger,
        onError: colors.onAccent,
        surface: colors.surface,
        onSurface: colors.textPrimary,
      ),
      extensions: <ThemeExtension<dynamic>>[
        colors,
        shapes,
        typography,
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SlateShapes.radiusLarge),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.surface,
        selectedItemColor: colors.accent,
        unselectedItemColor: colors.textTertiary,
        // Explícito a propósito (Decisión A10): con 3 destinos, Flutter
        // podría inferir `shifting` implícitamente si no se fija.
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.accent,
        foregroundColor: colors.onAccent,
        elevation: 4,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SlateShapes.radiusSmall),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SlateShapes.radiusSmall),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SlateShapes.radiusSmall),
          borderSide: BorderSide(color: colors.accent, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: textTheme.bodyMedium?.copyWith(color: colors.textTertiary),
      ),
      textTheme: textTheme,
      dividerTheme: DividerThemeData(
        color: colors.outline,
        thickness: 1,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.accent;
          }
          return colors.surfaceAlt;
        }),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(SlateShapes.radiusLarge),
          ),
        ),
      ),
    );
  }
}
