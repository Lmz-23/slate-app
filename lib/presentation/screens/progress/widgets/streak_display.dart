import 'package:flutter/material.dart';

import '../../../../core/theme/slate_shapes.dart';
import '../../../../core/theme/slate_theme_context.dart';
import '../../../../domain/entities/streak.dart';
import '../../../widgets/common/streak_mark.dart';

/// Bloque "Racha" de `/progress` (sistema-visual-fase3.md §1/§2.2).
///
/// Restilizado (Parte C, punto 7): usa [StreakMark] (variante grande) en vez
/// de `StreakBadge` — mismo átomo que ancla "racha" en Home, Progreso y la
/// bottom nav.
class StreakDisplay extends StatelessWidget {
  final Streak streak;

  const StreakDisplay({super.key, required this.streak});

  @override
  Widget build(BuildContext context) {
    final slate = context.slate;
    final shapes = context.slateShapes;
    final days = streak.currentStreak;

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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$days día${days == 1 ? '' : 's'} seguido${days == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: slate.textPrimary,
                ),
              ),
              const StreakMark(size: StreakMarkSize.large),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Tu racha más larga: ${streak.longestStreak} días',
            style: TextStyle(
              fontSize: 11,
              color: slate.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
