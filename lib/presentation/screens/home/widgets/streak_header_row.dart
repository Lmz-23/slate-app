import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/providers/streak_provider.dart';
import '../../../../core/theme/slate_theme_context.dart';
import '../../../widgets/common/streak_mark.dart';

/// "N días seguidos" + [StreakMark] pequeño (Decisión A3, tabla de
/// componentes). Sustituye a `StreakBadge` en la cabecera de progreso de Home.
class StreakHeaderRow extends ConsumerWidget {
  const StreakHeaderRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(streakProvider);
    final days = streak.currentStreak;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$days día${days == 1 ? '' : 's'} seguido${days == 1 ? '' : 's'}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.slate.textSecondary,
          ),
        ),
        const SizedBox(width: 6),
        const StreakMark(),
      ],
    );
  }
}
