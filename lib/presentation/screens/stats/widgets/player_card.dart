import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../domain/entities/player_profile.dart';
import '../../../../domain/enums/player_rank.dart';
import '../../../../application/services/player_xp_calculator.dart';

/// Tarjeta "Jugador" de Estadísticas (F2): nivel numérico + barra de XP
/// (progreso al siguiente nivel) + rango E→S por tramos.
///
/// Mantiene la identidad única Slate System: glifo ◆, textos del Sistema,
/// rango E→S. Se muestra JUNTO al [StreakDisplay] (complementa a la racha; no
/// la sustituye).
class PlayerCard extends StatelessWidget {
  final PlayerProfile profile;

  const PlayerCard({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final rank = PlayerXpCalculator.rankForLevel(profile.level);
    final intoLevel =
        PlayerXpCalculator.xpIntoLevel(profile.totalXp, profile.level);
    final spanLevel =
        PlayerXpCalculator.xpSpanForLevel(profile.level);
    final progress = PlayerXpCalculator.progressToNextLevel(
      profile.totalXp,
      profile.level,
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surface,
            AppColors.surfaceLight.withValues(alpha: 0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '◆ Jugador',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  'Nivel ${profile.level}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _RankBadge(rank: rank),
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
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Flexible(
                child: Text(
                  '$intoLevel / $spanLevel XP',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Chip del rango E→S (tramos de decisión A: 1-9 E, 10-19 D, 20-29 C,
/// 30-49 B, 50-69 A, 70+ S).
class _RankBadge extends StatelessWidget {
  final PlayerRank rank;

  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        'Rango ${rank.displayName}',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryLight,
        ),
      ),
    );
  }
}