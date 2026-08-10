import 'package:flutter/material.dart';
import '../../../application/services/thematic_texts_catalog.dart';
import '../../../core/constants/app_colors.dart';

/// Muestra el SnackBar "◆ Nivel subió" (F2).
///
/// Compartido entre TaskSection (tareas) y QuestCard (quest diaria) para que
/// CUALQUIER fuente de XP muestre el aviso exactamente igual y solo cuando el
/// level-up es NUEVO: los notifiers devuelven `null` cuando la transición al
/// nivel ya fue consumida ([PlayerProfile.shownLevelUps]), por lo que este
/// helper nunca duplica avisos.
void showLevelUpSnackBar(BuildContext context, int level) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          ThematicTextsCatalog.levelUpMessage(level),
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        backgroundColor: AppColors.surfaceLight,
        behavior: SnackBarBehavior.floating,
      ),
    );
}