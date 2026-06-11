import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class StreakBadge extends StatelessWidget {
  final int streakDays;
  final bool isLarge;

  const StreakBadge({
    super.key,
    required this.streakDays,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLarge ? 16 : 12,
        vertical: isLarge ? 8 : 6,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.streakFire, Color(0xFFFF8C42)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(isLarge ? 20 : 16),
        boxShadow: [
          BoxShadow(
            color: AppColors.streakFire.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department,
            color: Colors.white,
            size: isLarge ? 24 : 18,
          ),
          const SizedBox(width: 6),
          Text(
            '$streakDays',
            style: TextStyle(
              color: Colors.white,
              fontSize: isLarge ? 20 : 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (isLarge) ...[
            const SizedBox(width: 4),
            Text(
              'días',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }
}