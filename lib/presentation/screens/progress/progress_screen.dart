import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/player_provider.dart';
import '../../../application/providers/streak_provider.dart';
import '../../../application/providers/task_provider.dart';
import '../../../core/theme/slate_theme_context.dart';
import 'widgets/badge_vault.dart';
import 'widgets/daily_summary_row.dart';
import 'widgets/monthly_calendar.dart';
import 'widgets/player_card.dart';
import 'widgets/streak_display.dart';
import 'widgets/weekly_progress_section.dart';

/// Pantalla `/progress` (Decisión A10 — fusión de Weekly + Stats).
///
/// Scroll único, SIN tabs internos, en 7 bloques (sistema-visual-fase3.md
/// §2): cabecera, racha, progreso semanal, resumen por día, calendario
/// mensual, perfil (nivel+XP) e insignias.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slate = context.slate;
    final streak = ref.watch(streakProvider);
    final player = ref.watch(playerProvider);
    final badges = ref.watch(badgesProvider);
    final tasks = ref.watch(tasksProvider);

    return Scaffold(
      backgroundColor: slate.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 24),
              // 2. Racha
              StreakDisplay(streak: streak),
              const SizedBox(height: 24),
              // 3. Progreso semanal
              const WeeklyProgressSection(),
              const SizedBox(height: 24),
              // 4. Resumen por día de la semana
              const DailySummaryRow(),
              const SizedBox(height: 24),
              // 5. Calendario mensual
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: slate.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: context.slateShapes.cardShadow,
                ),
                child: MonthlyCalendar(tasks: tasks.cast()),
              ),
              const SizedBox(height: 24),
              // 6. Perfil (nivel + XP)
              PlayerCard(profile: player),
              const SizedBox(height: 24),
              // 7. Insignias
              BadgeVault(badges: badges),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final slate = context.slate;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Progreso',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: slate.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Tu constancia esta semana',
            style: TextStyle(
              fontSize: 12.5,
              color: slate.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
