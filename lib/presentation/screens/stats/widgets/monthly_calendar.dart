import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../domain/entities/task.dart';
import '../../../../application/providers/now_provider.dart';
import '../../../../application/providers/visible_month_provider.dart';

/// Calendario mensual de la pantalla de Estadísticas.
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
class MonthlyCalendar extends ConsumerWidget {
  /// Todas las tareas de la app. El filtrado por mes/año visible ocurre aquí.
  final List<Task> tasks;

  const MonthlyCalendar({super.key, required this.tasks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              icon: const Icon(Icons.chevron_left, color: AppColors.textSecondary),
            ),
            Expanded(
              child: Text(
                '${_getMonthName(visibleMonth.month)} ${visibleMonth.year}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
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
              icon: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ),
            TextButton(
              onPressed: () {
                ref.read(visibleMonthProvider.notifier).goToToday();
              },
              child: const Text('Hoy'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['D', 'L', 'M', 'X', 'J', 'V', 'S']
              .map((d) => SizedBox(
                    width: 40,
                    child: Text(
                      d,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: AppSpacing.sm),
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

            return _buildDayCell(day, dayTasks, isToday);
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

  Widget _buildDayCell(int day, List<Task> dayTasks, bool isToday) {
    final hasAllCompleted = dayTasks.isNotEmpty && dayTasks.every((t) => t.isCompleted);

    return Container(
      decoration: BoxDecoration(
        color: isToday
            ? AppColors.primary.withValues(alpha: 0.2)
            : hasAllCompleted
                ? AppColors.success.withValues(alpha: 0.1)
                : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: isToday ? Border.all(color: AppColors.primary, width: 1) : null,
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              day.toString(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: isToday ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ),
          if (dayTasks.isNotEmpty)
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
                      color: hasAllCompleted ? AppColors.success : AppColors.warning,
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
