import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../domain/entities/task.dart';

class MonthlyCalendar extends StatelessWidget {
  final List<Task> tasks;

  const MonthlyCalendar({super.key, required this.tasks});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final firstWeekday = DateTime(now.year, now.month, 1).weekday % 7;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getMonthName(now.month),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
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
            final dayTasks = _getTasksForDay(day);

            return _buildDayCell(day, dayTasks, now.day == day);
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

  List<Task> _getTasksForDay(int day) {
    final now = DateTime.now();
    return tasks.where((t) {
      return t.scheduledDate.year == now.year &&
          t.scheduledDate.month == now.month &&
          t.scheduledDate.day == day;
    }).toList();
  }

  Widget _buildDayCell(int day, List<Task> dayTasks, bool isToday) {
    final hasCompleted = dayTasks.any((t) => t.isCompleted);
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