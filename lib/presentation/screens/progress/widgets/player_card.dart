import 'package:flutter/material.dart';

import '../../../../core/theme/slate_shapes.dart';
import '../../../../core/theme/slate_theme_context.dart';
import '../../../../domain/entities/player_profile.dart';
import '../../../../application/services/player_xp_calculator.dart';

/// Bloque "Perfil" de `/progress` (sistema-visual-fase3.md §1/§2.6): nivel
/// numérico + barra de progreso al siguiente nivel + XP total.
///
/// Restilizado (Decisión A3/A9, Parte C): SIN rango E→S, SIN glifo ◆, SIN
/// etiqueta "◆ JUGADOR" — la gamificación se lee como información de
/// progreso, con el mismo tratamiento visual que cualquier otra métrica de
/// la app. CERO cambios en `PlayerProfile`/`PlayerXpCalculator`.
class PlayerCard extends StatelessWidget {
  final PlayerProfile profile;

  const PlayerCard({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final slate = context.slate;
    final shapes = context.slateShapes;

    final intoLevel =
        PlayerXpCalculator.xpIntoLevel(profile.totalXp, profile.level);
    final spanLevel = PlayerXpCalculator.xpSpanForLevel(profile.level);
    final progress = PlayerXpCalculator.progressToNextLevel(
      profile.totalXp,
      profile.level,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: slate.surface,
        borderRadius: BorderRadius.circular(SlateShapes.radiusLarge),
        boxShadow: shapes.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Nivel ${profile.level}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: slate.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$intoLevel / $spanLevel XP',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: slate.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: slate.surfaceAlt,
              valueColor: AlwaysStoppedAnimation<Color>(slate.accent),
            ),
          ),
        ],
      ),
    );
  }
}
