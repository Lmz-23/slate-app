import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/extensions/datetime_extensions.dart';
import '../../../application/providers/task_provider.dart';
import '../../../application/providers/streak_provider.dart';
import '../home/widgets/task_section.dart';

class WeeklyScreen extends ConsumerWidget {
  const WeeklyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final tasks = ref.watch(tasksProvider);
    final streak = ref.watch(streakProvider);

    final weekDays = _getWeekDays(selectedDate);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(streak),
            const SizedBox(height: AppSpacing.md),
            _buildWeekNavigation(context, ref, weekDays, selectedDate),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: Row(
                children: weekDays.map((date) {
                  final dayTasks = tasks.where((t) {
                    return t.scheduledDate.year == date.year &&
                        t.scheduledDate.month == date.month &&
                        t.scheduledDate.day == date.day;
                  }).toList();

                  final completed = dayTasks.where((t) => t.isCompleted).length;
                  final total = dayTasks.length;
                  final progress = total > 0 ? completed / total : 0.0;

                  return Expanded(
                    child: _buildDayColumn(
                      context,
                      ref,
                      date,
                      dayTasks,
                      progress,
                      date.isSameDay(selectedDate),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<DateTime> _getWeekDays(DateTime date) {
    final monday = date.subtract(Duration(days: (date.weekday - 1) % 7));
    return List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  Widget _buildHeader(dynamic streak) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Semana',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          Row(
            children: [
              const Icon(Icons.local_fire_department, color: AppColors.streakFire, size: 20),
              const SizedBox(width: 4),
              Text(
                '${streak.currentStreak} días',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeekNavigation(
    BuildContext context,
    WidgetRef ref,
    List<DateTime> weekDays,
    DateTime selectedDate,
  ) {
    final weekStart = weekDays.first;
    final weekEnd = weekDays.last;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () {
              ref.read(selectedDateProvider.notifier).state =
                  selectedDate.subtract(const Duration(days: 7));
            },
            icon: const Icon(Icons.chevron_left, color: AppColors.textSecondary),
          ),
          Text(
            '${weekStart.formattedDate} - ${weekEnd.formattedDate}',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          IconButton(
            onPressed: () {
              ref.read(selectedDateProvider.notifier).state =
                  selectedDate.add(const Duration(days: 7));
            },
            icon: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildDayColumn(
    BuildContext context,
    WidgetRef ref,
    DateTime date,
    List<dynamic> tasks,
    double progress,
    bool isSelected,
  ) {
    final isToday = date.isSameDay(DateTime.now());

    return GestureDetector(
      onTap: () {
        ref.read(selectedDateProvider.notifier).state = date;
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isToday ? Border.all(color: AppColors.primary, width: 1) : null,
        ),
        child: Column(
          children: [
            Text(
              ['L', 'M', 'X', 'J', 'V', 'S', 'D'][date.weekday % 7],
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isToday ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              date.day.toString(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            _buildProgressIndicator(progress),
            const SizedBox(height: 4),
            Text(
              '${tasks.length}',
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(double progress) {
    return SizedBox(
      width: 30,
      height: 30,
      child: CircularProgressIndicator(
        value: progress,
        strokeWidth: 3,
        backgroundColor: AppColors.surfaceLight,
        valueColor: AlwaysStoppedAnimation(
          progress >= 1.0 ? AppColors.success : AppColors.primary,
        ),
      ),
    );
  }
}