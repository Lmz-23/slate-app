import 'package:flutter/material.dart' hide Badge;
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../domain/entities/badge.dart';
import '../../../../domain/entities/user_settings.dart';
import '../../../../domain/enums/badge_type.dart';
import 'badge_presentation.dart';

class BadgeVault extends StatelessWidget {
  final List<Badge> badges;

  /// Ajustes del usuario para la resolución de nombre/icono (config IA →
  /// nomenclatura Slate System → canónico). Por defecto tema OFF: los nombres
  /// canónicos actuales.
  final UserSettings settings;

  const BadgeVault({
    super.key,
    required this.badges,
    this.settings = const UserSettings(),
  });

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
    // Resolución centralizada: config IA → nomenclatura SL → canónico.
    final displayName = BadgePresentation.resolveName(type: type, settings: settings);
    final flavor = BadgePresentation.resolveFlavor(type: type, settings: settings);
    final iconData = BadgePresentation.resolveIconData(type: type, settings: settings);

    final subtitle = flavor != null
        ? '$flavor · ${type.requiredDays} días'
        : '${type.requiredDays} días';

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
            isUnlocked ? displayName : '???',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isUnlocked ? AppColors.textPrimary : AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}