import 'package:flutter/material.dart';

import '../../../core/theme/slate_shapes.dart';
import '../../../core/theme/slate_theme_context.dart';

/// Muestra el SnackBar "por defecto" del nuevo sistema visual
/// (sistema-visual-fase3.md §6): fondo `surface` en claro (con sombra),
/// `surfaceAlt` en oscuro (para diferenciarse de `background`, que no tiene
/// sombra); radio 14; texto 13px/600 `textPrimary`.
///
/// Si se pasa [actionLabel]/[onAction], se añade la acción de texto (p. ej.
/// "DESHACER") en `accent`/700 uppercase, sin fondo de botón — mismo patrón
/// que el SnackBar de Material estándar, solo recoloreado.
void showSlateSnackBar(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 4),
}) {
  final slate = context.slate;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: slate.textPrimary,
          ),
        ),
        backgroundColor: isDark ? slate.surfaceAlt : slate.surface,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SlateShapes.radiusSmall),
        ),
        action: actionLabel != null
            ? SnackBarAction(
                label: actionLabel.toUpperCase(),
                textColor: slate.accent,
                onPressed: onAction ?? () {},
              )
            : null,
      ),
    );
}
