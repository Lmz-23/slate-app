import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/extensions/datetime_extensions.dart';
import '../../../core/theme/slate_shapes.dart';
import '../../../core/theme/slate_theme_context.dart';
import '../../../application/providers/task_provider.dart';
import '../../../application/providers/now_provider.dart';
import '../task_form/task_form_sheet.dart';
import 'widgets/daily_progress_card.dart';
import 'widgets/task_section.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final scheduledTasks = ref.watch(scheduledTasksProvider);
    final unscheduledTasks = ref.watch(unscheduledTasksProvider);
    final slate = context.slate;

    return Scaffold(
      backgroundColor: slate.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, ref, selectedDate),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const DailyProgressCard(),
                    const SizedBox(height: AppSpacing.lg),
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
                      _buildEmptyState(context),
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
  ) {
    final now = ref.watch(nowProvider).value ?? DateTime.now();
    final slate = context.slate;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            date.relativeDay(now: now),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: slate.textPrimary,
            ),
          ),
          Text(
            date.formattedDate,
            style: TextStyle(
              fontSize: 12.5,
              color: slate.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildDateSelector(context, ref, date),
        ],
      ),
    );
  }

  /// Genera las fechas de la semana centrada en [selectedDate] (±3 días).
  /// Método estático para evitar recrear la lista en cada build.
  static List<DateTime> _generateWeekDates(DateTime selectedDate) {
    final anchor = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    return List.generate(7, (i) => anchor.add(Duration(days: i - 3)));
  }

  Widget _buildDateSelector(BuildContext context, WidgetRef ref, DateTime selectedDate) {
    final now = ref.watch(nowProvider).value ?? DateTime.now();
    final slate = context.slate;

    // La franja de 7 días se centra en la FECHA SELECCIONADA (selectedDate ± 3),
    // no en el día actual, para que al navegar a una fecha lejana la franja
    // muestre los días cercanos a dicha fecha.
    final dates = _generateWeekDates(selectedDate);

    return Row(
      children: [
        IconButton(
          onPressed: () {
            ref.read(selectedDateProvider.notifier).state =
                selectedDate.subtract(const Duration(days: 7));
          },
          icon: Icon(Icons.chevron_left, color: slate.textSecondary),
          tooltip: 'Semana anterior',
        ),
        Expanded(
          child: Row(
            children: dates.map((date) {
              final isSelected = date.year == selectedDate.year &&
                  date.month == selectedDate.month &&
                  date.day == selectedDate.day;
              final isToday = date.isSameDay(now);

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: GestureDetector(
                    onTap: () {
                      ref.read(selectedDateProvider.notifier).state = date;
                    },
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: isSelected ? slate.accent : slate.surface,
                        borderRadius: BorderRadius.circular(
                          SlateShapes.radiusSmall,
                        ),
                        border: isToday && !isSelected
                            ? Border.all(color: slate.todayAccent, width: 1)
                            : null,
                        boxShadow: isSelected ? context.slateShapes.cardShadow : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            const ['L', 'M', 'X', 'J', 'V', 'S', 'D'][date.weekday - 1],
                            style: TextStyle(
                              fontSize: 11,
                              color: isSelected
                                  ? slate.onAccent.withValues(alpha: 0.7)
                                  : slate.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            date.day.toString(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? slate.onAccent : slate.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        IconButton(
          onPressed: () {
            ref.read(selectedDateProvider.notifier).state =
                selectedDate.add(const Duration(days: 7));
          },
          icon: Icon(Icons.chevron_right, color: slate.textSecondary),
          tooltip: 'Semana siguiente',
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final slate = context.slate;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 40,
              color: slate.textTertiary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Sin tareas para hoy',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: slate.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Toca + para agregar una tarea',
              style: TextStyle(
                fontSize: 12,
                color: slate.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAB(BuildContext context, WidgetRef ref, DateTime date) {
    return FloatingActionButton(
      heroTag: 'add',
      onPressed: () => _showTaskForm(context, ref, date),
      child: const Icon(Icons.add),
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
}
