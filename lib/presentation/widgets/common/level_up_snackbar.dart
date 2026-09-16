import 'package:flutter/material.dart';

import '../../../core/theme/slate_theme_context.dart';
import 'streak_mark.dart';

/// Muestra el SnackBar de subida de nivel (sistema-visual-fase3.md §6).
///
/// Compartido entre TaskSection (tareas) y el auto-reclamo de la quest para
/// que CUALQUIER fuente de XP muestre el aviso exactamente igual y solo
/// cuando el level-up es NUEVO: los notifiers devuelven `null` cuando la
/// transición al nivel ya fue consumida ([PlayerProfile.shownLevelUps]), por
/// lo que este helper nunca duplica avisos.
///
/// Restilizado (Parte C, punto 10): único snackbar con fondo `accent` pleno
/// (se gana la excepción por ser un evento poco frecuente, igual que el FAB);
/// sin lenguaje RPG, sin ícono de trofeo — el glifo es el mismo rombo de
/// [StreakMark], reforzando que es "una marca de progreso más".
void showLevelUpSnackBar(BuildContext context, int level) {
  final slate = context.slate;
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            StreakMark(size: StreakMarkSize.small, color: slate.onAccent),
            const SizedBox(width: 8),
            Text(
              'Subiste a nivel $level',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: slate.onAccent,
              ),
            ),
          ],
        ),
        backgroundColor: slate.accent,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
}