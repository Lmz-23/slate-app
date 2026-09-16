import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/providers/now_provider.dart';
import '../../../../application/providers/progress_week_days_provider.dart';
import '../../../../application/providers/task_provider.dart';
import '../../../../core/extensions/datetime_extensions.dart';
import '../../../../core/theme/slate_shapes.dart';
import '../../../../core/theme/slate_theme_context.dart';

/// Bloque "Resumen por día de la semana" de `/progress`
/// (sistema-visual-fase3.md §2.4): anillo de progreso PORCENTUAL por día
/// (a diferencia de `WeekActivityRow` de Home, que es binario activo/
/// inactivo — semánticas distintas, A10, no se fusionan).
///
/// Extraído de `weekly_screen.dart` (`_buildDailyProgressRow`/
/// `_buildDayColumn`, Fase 3a) como widget de sección propio.
class DailySummaryRow extends ConsumerWidget {
  const DailySummaryRow({super.key});

  static const _labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slate = context.slate;
    final shapes = context.slateShapes;
    final tasks = ref.watch(tasksProvider);
    final weekDays = ref.watch(progressWeekDaysProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final now = ref.watch(nowProvider).value ?? DateTime.now();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: slate.surface,
        borderRadius: BorderRadius.circular(SlateShapes.radiusLarge),
        boxShadow: shapes.cardShadow,
      ),
      child: Row(
        children: List.generate(7, (i) {
          final date = weekDays[i];
          final dayTasks = tasks.where((t) => t.scheduledDate.isSameDay(date)).toList();
          final completed = dayTasks.where((t) => t.isCompleted).length;
          final total = dayTasks.length;
          final progress = total > 0 ? completed / total : 0.0;
          final isSelected = date.isSameDay(selectedDate);
          final isToday = date.isSameDay(now);

          return Expanded(
            child: GestureDetector(
              onTap: () {
                ref.read(selectedDateProvider.notifier).state = date;
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _labels[i],
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                      color: isToday ? slate.todayAccent : slate.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: 1,
                          strokeWidth: 3,
                          color: slate.surfaceAlt,
                        ),
                        CircularProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          strokeWidth: 3,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(slate.success),
                        ),
                        Text(
                          '$completed',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? slate.accent : slate.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
