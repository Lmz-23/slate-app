import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/providers/progress_week_days_provider.dart';
import '../../../../application/providers/task_provider.dart';
import '../../../../application/providers/weekly_progress_provider.dart';
import '../../../../core/extensions/datetime_extensions.dart';
import '../../../../core/theme/slate_shapes.dart';
import '../../../../core/theme/slate_theme_context.dart';

/// Bloque "Progreso semanal" de `/progress` (sistema-visual-fase3.md §2.3):
/// navegación de semana + barra de porcentaje.
///
/// Extraído de `weekly_screen.dart` (Fase 3a, Addendum 1 A10): la navegación
/// mueve `selectedDateProvider` (mismo selector que gobierna Home —
/// acoplamiento preexistente, documentado en A10/RG19, fuera de alcance). La
/// barra en sí refleja [weeklyProgressProvider], que SIEMPRE mide la semana
/// en curso, independiente de la semana navegada.
class WeeklyProgressSection extends ConsumerWidget {
  const WeeklyProgressSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slate = context.slate;
    final shapes = context.slateShapes;
    final selectedDate = ref.watch(selectedDateProvider);
    final weekDays = ref.watch(progressWeekDaysProvider);
    final progress = ref.watch(weeklyProgressProvider);

    final weekStart = weekDays.first;
    final weekEnd = weekDays.last;

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
              IconButton(
                onPressed: () {
                  ref.read(selectedDateProvider.notifier).state =
                      selectedDate.subtract(const Duration(days: 7));
                },
                icon: Icon(Icons.chevron_left, size: 17, color: slate.textTertiary),
              ),
              Text(
                '${weekStart.formattedDate} - ${weekEnd.formattedDate}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: slate.textPrimary,
                ),
              ),
              IconButton(
                onPressed: () {
                  ref.read(selectedDateProvider.notifier).state =
                      selectedDate.add(const Duration(days: 7));
                },
                icon: Icon(Icons.chevron_right, size: 17, color: slate.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            // Nota: la fracción es de TAREAS (no de días) — misma base de
            // datos que `_calculateWeeklyProgress` original; el texto evita
            // prometer "días" cuando la métrica real es de tareas (mismo
            // criterio de honestidad que `DailyProgressBar`, A3).
            '${progress.completed} de ${progress.total} tareas completadas esta semana',
            style: TextStyle(fontSize: 11, color: slate.textSecondary),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.ratio,
              minHeight: 8,
              backgroundColor: slate.surfaceAlt,
              valueColor: AlwaysStoppedAnimation<Color>(slate.success),
            ),
          ),
        ],
      ),
    );
  }
}
