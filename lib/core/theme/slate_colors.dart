import 'package:flutter/material.dart';

import 'tokens/slate_palette.dart';

/// Tokens semánticos de color del nuevo sistema visual de slate-app.
///
/// Sustituye el acceso estático a `AppColors` (que no es sensible al
/// brillo) por un [ThemeExtension] real, de forma que "claro vs. oscuro"
/// se resuelve por [ThemeData] y no por que cada widget elija a mano una
/// variante. Ver Decisión A1 de
/// docs/architecture/rediseno-identidad-visual.md.
///
/// Acceso recomendado: `context.slate` (ver `slate_theme_context.dart`) en
/// vez de `Theme.of(context).extension<SlateColors>()` directamente.
@immutable
class SlateColors extends ThemeExtension<SlateColors> {
  const SlateColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.outline,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.onAccent,
    required this.success,
    required this.onSuccess,
    required this.todayAccent,
    required this.priorityHigh,
    required this.priorityMedium,
    required this.danger,
  });

  /// Fondo de pantalla.
  final Color background;

  /// Tarjetas, tiles, hoja de formulario.
  final Color surface;

  /// Píldoras/contadores, track de barras de progreso.
  final Color surfaceAlt;

  /// Bordes de checkbox vacío, indicador de día vacío.
  final Color outline;

  /// Títulos, texto principal.
  final Color textPrimary;

  /// Subtítulos, etiquetas de sección.
  final Color textSecondary;

  /// Metadatos (hora, día no seleccionado, texto tachado).
  final Color textTertiary;

  /// Día seleccionado, FAB, StreakMark, progreso de nivel, foco.
  final Color accent;

  /// Texto/ícono sobre [accent].
  final Color onAccent;

  /// Check de completado, barra de progreso diario, punto de calendario
  /// con actividad.
  final Color success;

  /// Ícono de check sobre [success].
  final Color onSuccess;

  /// Énfasis del día actual dentro de filas semanales.
  final Color todayAccent;

  /// Punto de prioridad alta.
  final Color priorityHigh;

  /// Punto de prioridad media.
  final Color priorityMedium;

  /// Fondo de swipe-to-delete, botón destructivo, borde de error.
  final Color danger;

  static const SlateColors light = SlateColors(
    background: SlatePalette.backgroundLight,
    surface: SlatePalette.surfaceLight,
    surfaceAlt: SlatePalette.surfaceAltLight,
    outline: SlatePalette.outlineLight,
    textPrimary: SlatePalette.textPrimaryLight,
    textSecondary: SlatePalette.textSecondaryLight,
    textTertiary: SlatePalette.textTertiaryLight,
    accent: SlatePalette.accentLight,
    onAccent: SlatePalette.onAccent,
    success: SlatePalette.successLight,
    onSuccess: SlatePalette.onSuccessLight,
    todayAccent: SlatePalette.todayAccentLight,
    priorityHigh: SlatePalette.priorityHighLight,
    priorityMedium: SlatePalette.priorityMediumLight,
    danger: SlatePalette.dangerLight,
  );

  static const SlateColors dark = SlateColors(
    background: SlatePalette.backgroundDark,
    surface: SlatePalette.surfaceDark,
    surfaceAlt: SlatePalette.surfaceAltDark,
    outline: SlatePalette.outlineDark,
    textPrimary: SlatePalette.textPrimaryDark,
    textSecondary: SlatePalette.textSecondaryDark,
    textTertiary: SlatePalette.textTertiaryDark,
    accent: SlatePalette.accentDark,
    onAccent: SlatePalette.onAccent,
    success: SlatePalette.successDark,
    onSuccess: SlatePalette.onSuccessDark,
    todayAccent: SlatePalette.todayAccentDark,
    priorityHigh: SlatePalette.priorityHighDark,
    priorityMedium: SlatePalette.priorityMediumDark,
    danger: SlatePalette.dangerDark,
  );

  /// Resuelve [SlateColors] desde el [BuildContext] con fallback obligatorio
  /// a [SlateColors.dark]. Nunca usar `Theme.of(context).extension<...>()!`:
  /// un `ThemeData` ajeno (p. ej. en un test de widget sin el tema de la app)
  /// haría crashear la app en vez de degradar con gracia.
  static SlateColors of(BuildContext context) {
    return Theme.of(context).extension<SlateColors>() ?? SlateColors.dark;
  }

  @override
  SlateColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? outline,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? accent,
    Color? onAccent,
    Color? success,
    Color? onSuccess,
    Color? todayAccent,
    Color? priorityHigh,
    Color? priorityMedium,
    Color? danger,
  }) {
    return SlateColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      outline: outline ?? this.outline,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      todayAccent: todayAccent ?? this.todayAccent,
      priorityHigh: priorityHigh ?? this.priorityHigh,
      priorityMedium: priorityMedium ?? this.priorityMedium,
      danger: danger ?? this.danger,
    );
  }

  @override
  SlateColors lerp(ThemeExtension<SlateColors>? other, double t) {
    if (other is! SlateColors) return this;
    return SlateColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      todayAccent: Color.lerp(todayAccent, other.todayAccent, t)!,
      priorityHigh: Color.lerp(priorityHigh, other.priorityHigh, t)!,
      priorityMedium: Color.lerp(priorityMedium, other.priorityMedium, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}
