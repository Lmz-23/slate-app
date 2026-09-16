import 'package:flutter/material.dart';

import '../../../../core/theme/slate_shapes.dart';
import '../../../../core/theme/slate_theme_context.dart';
import 'daily_progress_bar.dart';
import 'streak_header_row.dart';
import 'week_activity_row.dart';

/// Tarjeta unificada de progreso de "Hoy" (Decisión A3/A4): compone
/// [StreakHeaderRow] + [DailyProgressBar] + [WeekActivityRow]. Sustituye a
/// `QuestCard` + `StreakBadge` en la cabecera de Home.
class DailyProgressCard extends StatelessWidget {
  const DailyProgressCard({super.key});

  @override
  Widget build(BuildContext context) {
    final slate = context.slate;
    final shapes = context.slateShapes;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: slate.surface,
        borderRadius: BorderRadius.circular(SlateShapes.radiusLarge),
        boxShadow: shapes.cardShadow,
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreakHeaderRow(),
          SizedBox(height: 12),
          DailyProgressBar(),
          SizedBox(height: 14),
          WeekActivityRow(),
        ],
      ),
    );
  }
}
