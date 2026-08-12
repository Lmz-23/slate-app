import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/extensions/datetime_extensions.dart';
import '../../../application/providers/task_provider.dart';
import '../../../application/providers/streak_provider.dart';
import '../../../application/providers/now_provider.dart';
import '../stats/widgets/monthly_calendar.dart';

class WeeklyScreen extends ConsumerWidget {
  const WeeklyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final tasks = ref.watch(tasksProvider);
    final streak = ref.watch(streakProvider);
    final now = ref.watch(nowProvider).value ?? DateTime.now();

    final weekDays = _getWeekDays(selectedDate);
    final weeklyProgress = _calculateWeeklyProgress(tasks, now);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(streak),
              const SizedBox(height: AppSpacing.md),
              _buildWeekNavigation(context, ref, weekDays, selectedDate),
              const SizedBox(height: AppSpacing.md),
              _buildWeeklyProgress(weeklyProgress),
              const SizedBox(height: AppSpacing.lg),
              MonthlyCalendar(tasks: tasks.cast()),
              const SizedBox(height: AppSpacing.md),
              _buildDailyProgressHeader(),
              _buildDailyProgressRow(ref, tasks, selectedDate, weekDays),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  // Progreso semanal (barra superior): fracción de tareas COMPLETADAS sobre
  // el total de las programadas en la semana EN CURSO. La ventana va del
  // inicio de la semana (`now.weekday % 7`, domingo como día 0) hasta HOY:
  // los días futuros de la semana se excluyen a propósito porque aún no
  // tienen resultado (la barra muestra el avance real de lo transcurrido).
  double _calculateWeeklyProgress(List<dynamic> tasks, DateTime now) {
    if (tasks.isEmpty) return 0.0;
    final weekStart = now.subtract(Duration(days: now.weekday % 7));
    final weekTasks = tasks.where((t) {
      return t.scheduledDate.isAfter(weekStart.subtract(const Duration(days: 1))) &&
          t.scheduledDate.isBefore(now.add(const Duration(days: 1)));
    }).toList();

    if (weekTasks.isEmpty) return 0.0;
    final completed = weekTasks.where((t) => t.isCompleted).length;
    return completed / weekTasks.length;
  }

  Widget _buildWeeklyProgress(double progress) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Progreso semanal',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.surfaceLight,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyProgressHeader() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          Text(
            'Resumen diario',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyProgressRow(
    WidgetRef ref,
    List<dynamic> tasks,
    DateTime selectedDate,
    List<DateTime> weekDays,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
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
              ref,
              date,
              dayTasks,
              progress,
              date.isSameDay(selectedDate),
            ),
          );
        }).toList(),
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
            'Mi Progreso',
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
    WidgetRef ref,
    DateTime date,
    List<dynamic> tasks,
    double progress,
    bool isSelected,
  ) {
    final now = ref.watch(nowProvider).value ?? DateTime.now();
    final isToday = date.isSameDay(now);

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
              const ['L', 'M', 'X', 'J', 'V', 'S', 'D'][date.weekday - 1],
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
          // Verde cuando el día quedó al 100 % (decisión de producto: de un
          // vistazo se ven los días cerrados completos); primario en parcial.
          progress >= 1.0 ? AppColors.success : AppColors.primary,
        ),
      ),
    );
  }
}