import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/providers/daily_progress_provider.dart';
import '../../../../core/theme/slate_theme_context.dart';

/// Texto + barra de progreso diario ([dailyProgressProvider]).
///
/// Estado "meta diaria cumplida" (sistema-visual-fase3.md §3): con el
/// auto-reclamo de la quest (A9) ya no hay botón "reclamar"; este es el único
/// feedback visual de que el día se completó, transformando el MISMO
/// elemento (sin confetti, sin modal, sin elemento nuevo).
class DailyProgressBar extends ConsumerWidget {
  const DailyProgressBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(dailyProgressProvider);
    final slate = context.slate;
    final goalMet = progress.isGoalMet;
    final ratio = progress.totalToday > 0
        ? (progress.completedToday / progress.totalToday).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (goalMet) ...[
              Icon(Icons.check, size: 14, color: slate.success),
              const SizedBox(width: 4),
            ],
            Text(
              goalMet
                  ? 'Meta diaria cumplida'
                  : '${progress.completedToday} de ${progress.totalToday} tareas completadas hoy',
              style: TextStyle(
                fontSize: 11,
                fontWeight: goalMet ? FontWeight.w700 : FontWeight.w400,
                color: goalMet ? slate.success : slate.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: goalMet ? 1.0 : ratio,
            minHeight: 6,
            backgroundColor: slate.surfaceAlt,
            valueColor: AlwaysStoppedAnimation<Color>(
              goalMet ? slate.success : slate.accent,
            ),
          ),
        ),
      ],
    );
  }
}
