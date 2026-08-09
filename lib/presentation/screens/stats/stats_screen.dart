import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../application/providers/streak_provider.dart';
import '../../../application/providers/settings_provider.dart';
import '../../../application/providers/task_provider.dart';
import '../../../application/providers/now_provider.dart';
import 'widgets/streak_display.dart';
import 'widgets/badge_vault.dart';
import 'widgets/monthly_calendar.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(streakProvider);
    final badges = ref.watch(badgesProvider);
    final tasks = ref.watch(tasksProvider);
    final now = ref.watch(nowProvider).value ?? DateTime.now();
    final settings = ref.watch(settingsProvider);

    final weeklyProgress = _calculateWeeklyProgress(tasks, now);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Estadísticas',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              StreakDisplay(streak: streak),
              const SizedBox(height: AppSpacing.lg),
              _buildWeeklyProgress(weeklyProgress),
              const SizedBox(height: AppSpacing.lg),
              MonthlyCalendar(tasks: tasks),
              const SizedBox(height: AppSpacing.lg),
              BadgeVault(badges: badges, settings: settings),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

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
}