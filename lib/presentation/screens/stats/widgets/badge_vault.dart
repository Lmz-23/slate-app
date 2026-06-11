import 'package:flutter/material.dart' hide Badge;
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../domain/entities/badge.dart';
import '../../../../domain/enums/badge_type.dart';

class BadgeVault extends StatelessWidget {
  final List<Badge> badges;

  const BadgeVault({super.key, required this.badges});

  @override
  Widget build(BuildContext context) {
    final allBadgeTypes = BadgeType.values;
    final unlockedIds = badges.map((b) => b.type).toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vitrina de insignias',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 0.8,
          ),
          itemCount: allBadgeTypes.length,
          itemBuilder: (context, index) {
            final badgeType = allBadgeTypes[index];
            final isUnlocked = unlockedIds.contains(badgeType);
            final badge = isUnlocked
                ? badges.firstWhere((b) => b.type == badgeType)
                : null;

            return _buildBadgeItem(badgeType, isUnlocked, badge);
          },
        ),
      ],
    );
  }

  Widget _buildBadgeItem(BadgeType type, bool isUnlocked, Badge? badge) {
    final iconData = _getIconData(type.iconName);

    return Container(
      decoration: BoxDecoration(
        color: isUnlocked ? AppColors.card : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: isUnlocked ? AppColors.streakGold.withValues(alpha: 0.3) : AppColors.surfaceLight,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            iconData,
            size: 32,
            color: isUnlocked ? AppColors.streakGold : AppColors.textTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 8),
          Text(
            isUnlocked ? type.name : '???',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isUnlocked ? AppColors.textPrimary : AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${type.requiredDays} días',
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'star':
        return Icons.star;
      case 'fire':
        return Icons.local_fire_department;
      case 'lightning':
        return Icons.bolt;
      case 'flower':
        return Icons.local_florist;
      case 'shield':
        return Icons.shield;
      case 'trophy':
        return Icons.emoji_events;
      case 'crown':
        return Icons.workspace_premium;
      case 'diamond':
        return Icons.diamond;
      case 'rocket':
        return Icons.rocket_launch;
      default:
        return Icons.star;
    }
  }
}