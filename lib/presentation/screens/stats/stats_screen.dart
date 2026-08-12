import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../application/providers/streak_provider.dart';
import '../../../application/providers/player_provider.dart';
import 'widgets/streak_display.dart';
import 'widgets/player_card.dart';
import 'widgets/badge_vault.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(streakProvider);
    final player = ref.watch(playerProvider);
    final badges = ref.watch(badgesProvider);

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
              // Layout vertical: la racha va sobre la tarjeta de Jugador.
              // Cada tarjeta usa TODO el ancho disponible, evitando el
              // overflow horizontal ("right overflowed") en pantallas
              // medianas/pequeñas que producía el Row con dos Expanded.
              StreakDisplay(streak: streak),
              const SizedBox(height: AppSpacing.lg),
              PlayerCard(profile: player),
              const SizedBox(height: AppSpacing.lg),
              BadgeVault(badges: badges),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}