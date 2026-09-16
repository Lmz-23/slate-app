import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/slate_theme_context.dart';
import '../../../../domain/entities/task.dart';
import '../../../../application/providers/now_provider.dart';
import '../../../../application/providers/visible_month_provider.dart';

/// Calendario mensual de `/progress` (sistema-visual-fase3.md §2.5).
///
/// Muestra los días del mes visible (controlado por [visibleMonthProvider]) y
/// marca los días con tareas según [tasks], filtradas por el mes/año visible.
///
/// Navegación (decisiones de producto):
/// - Flecha izquierda: mes anterior (libre).
/// - Flecha derecha: mes siguiente, deshabilitada cuando el mes visible es el
///   mes en curso (no se puede ir más allá del mes actual, C1a).
/// - Botón "Hoy": vuelve al mes en curso (C3a).
///
/// El resaltado de "hoy" solo se aplica cuando el mes visible es el mes en
/// curso y compara día + mes + año para no resaltar un día equivocado al
/// navegar a otro mes.
///
/// Restilizado (Parte C, punto 9): día actual con círculo de fondo `accent` y
/// número en `onAccent`; punto de actividad `success` (todas completadas) o
/// `priorityMedium` (actividad parcial), sin punto si ninguna tarea del día
/// está completada.
class MonthlyCalendar extends ConsumerWidget {
  /// Todas las tareas de la app. El filtrado por mes/año visible ocurre aquí.
  final List<Task> tasks;

  const MonthlyCalendar({super.key, required this.tasks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slate = context.slate;
    final visibleMonth = ref.watch(visibleMonthProvider);
    final now = ref.watch(nowProvider).value ?? DateTime.now();
    final canGoToNextMonth =
        ref.watch(visibleMonthProvider.notifier).canGoToNextMonth;

    final daysInMonth = DateTime(visibleMonth.year, visibleMonth.month + 1, 0).day;
    final firstWeekday = DateTime(visibleMonth.year, visibleMonth.month, 1).weekday % 7;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Mes anterior',
              onPressed: () {
                ref.read(visibleMonthProvider.notifier).goToPreviousMonth();
              },
              icon: Icon(Icons.chevron_left, color: slate.textSecondary),
            ),
            Expanded(
              child: Text(
                '${_getMonthName(visibleMonth.month)} ${visibleMonth.year}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: slate.textPrimary,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Mes siguiente',
              onPressed: canGoToNextMonth
                  ? () {
                      ref.read(visibleMonthProvider.notifier).goToNextMonth();
                    }
                  : null,
              icon: Icon(Icons.chevron_right, color: slate.textSecondary),
            ),
            TextButton(
              onPressed: () {
                ref.read(visibleMonthProvider.notifier).goToToday();
              },
              child: Text('Hoy', style: TextStyle(color: slate.accent)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['D', 'L', 'M', 'X', 'J', 'V', 'S']
              .map((d) => SizedBox(
                    width: 40,
                    child: Text(
                      d,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: slate.textSecondary,
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: firstWeekday + daysInMonth,
          itemBuilder: (context, index) {
            if (index < firstWeekday) {
              return const SizedBox.shrink();
            }
            final day = index - firstWeekday + 1;
            final dayTasks = _getTasksForDay(visibleMonth, day);
            final dayDate = DateTime(visibleMonth.year, visibleMonth.month, day);
            final isToday = dayDate.year == now.year &&
                dayDate.month == now.month &&
                dayDate.day == now.day;

            return _buildDayCell(context, day, dayTasks, isToday);
          },
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return months[month - 1];
  }

  List<Task> _getTasksForDay(DateTime visibleMonth, int day) {
    return tasks.where((t) {
      return t.scheduledDate.year == visibleMonth.year &&
          t.scheduledDate.month == visibleMonth.month &&
          t.scheduledDate.day == day;
    }).toList();
  }

  Widget _buildDayCell(
    BuildContext context,
    int day,
    List<Task> dayTasks,
    bool isToday,
  ) {
    final slate = context.slate;
    final completedCount = dayTasks.where((t) => t.isCompleted).length;
    final hasAllCompleted = dayTasks.isNotEmpty && completedCount == dayTasks.length;

    return Container(
      decoration: BoxDecoration(
        color: isToday ? slate.accent : Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              day.toString(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: isToday ? slate.onAccent : slate.textPrimary,
              ),
            ),
          ),
          if (completedCount > 0)
            Positioned(
              bottom: 4,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasAllCompleted ? slate.success : slate.priorityMedium,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
