import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/extensions/datetime_extensions.dart';
import '../../../application/providers/task_provider.dart';
import '../../../application/providers/streak_provider.dart';
import '../../widgets/task_tile.dart';
import '../../widgets/streak_badge.dart';
import '../task_form/task_form_sheet.dart';
import 'widgets/task_section.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final streak = ref.watch(streakProvider);
    final scheduledTasks = ref.watch(scheduledTasksProvider);
    final unscheduledTasks = ref.watch(unscheduledTasksProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, ref, selectedDate, streak),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (scheduledTasks.isNotEmpty) ...[
                      TaskSection(
                        title: 'Con horario',
                        tasks: scheduledTasks,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    if (unscheduledTasks.isNotEmpty) ...[
                      TaskSection(
                        title: 'Sin horario',
                        tasks: unscheduledTasks,
                      ),
                    ],
                    if (scheduledTasks.isEmpty && unscheduledTasks.isEmpty)
                      _buildEmptyState(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(context, ref, selectedDate),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    DateTime date,
    dynamic streak,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    date.relativeDay,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    date.formattedDate,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              StreakBadge(streakDays: streak.currentStreak),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildDateSelector(context, ref, date),
        ],
      ),
    );
  }

  Widget _buildDateSelector(BuildContext context, WidgetRef ref, DateTime selectedDate) {
    final today = DateTime.now();
    final dates = List.generate(7, (i) {
      return today.add(Duration(days: i - 3));
    });

    return SizedBox(
      height: 70,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: dates.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final date = dates[index];
          final isSelected = date.year == selectedDate.year &&
              date.month == selectedDate.month &&
              date.day == selectedDate.day;
          final isToday = date.isSameDay(today);

          return GestureDetector(
            onTap: () {
              ref.read(selectedDateProvider.notifier).state = date;
            },
            child: Container(
              width: 50,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: isToday && !isSelected
                    ? Border.all(color: AppColors.primary, width: 1)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    ['L', 'M', 'X', 'J', 'V', 'S', 'D'][date.weekday % 7],
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.7)
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date.day.toString(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 80,
              color: AppColors.textTertiary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Sin tareas para hoy',
              style: TextStyle(
                fontSize: 18,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Toca + para agregar una tarea',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAB(BuildContext context, WidgetRef ref, DateTime date) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.small(
          heroTag: 'voice',
          onPressed: () => _showVoiceInput(context, ref, date),
          backgroundColor: AppColors.surface,
          child: const Icon(Icons.mic, color: AppColors.primary),
        ),
        const SizedBox(height: 12),
        FloatingActionButton(
          heroTag: 'add',
          onPressed: () => _showTaskForm(context, ref, date),
          child: const Icon(Icons.add),
        ),
      ],
    );
  }

  void _showTaskForm(BuildContext context, WidgetRef ref, DateTime date, {String? taskId}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TaskFormSheet(
        initialDate: date,
        taskId: taskId,
      ),
    );
  }

  void _showVoiceInput(BuildContext context, WidgetRef ref, DateTime date) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TaskFormSheet(
        initialDate: date,
        isVoiceMode: true,
      ),
    );
  }
}