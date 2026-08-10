import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/providers/quest_provider.dart';
import '../../../../application/services/quest_calculator.dart';
import '../../../../application/services/thematic_texts_catalog.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../widgets/common/level_up_snackbar.dart';
import '../../../widgets/common/slate_card.dart';

/// Tarjeta de la QUEST DIARIA del Sistema (F3, decisión C).
///
/// Aparece en Home SOLO si la quest es visible hoy (≥3 tareas programadas,
/// decisión tomada al inicio del día y persistente). Muestra el título temático
/// "▶ Daily Quest", el progreso de completados del día y:
/// - si aún no se cumplen las 3: solo el progreso (sin botón);
/// - si se cumplen y no se ha reclamado: botón "▶ Reclamar +25 XP";
/// - si ya se reclamó: estado reclamado con glifo ◆.
///
/// Al reclamar se usa el mismo método de XP de F2 ([QuestNotifier.claim] →
/// [PlayerNotifier.addQuestXp]) que reutiliza `shownLevelUps`: el SnackBar de
/// nivel solo aparece cuando el +25 cruza un nivel NUEVO.
class QuestCard extends ConsumerWidget {
  const QuestCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quest = ref.watch(questProvider);
    if (!quest.isVisible) return const SizedBox.shrink();

    return SlateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ThematicTextsCatalog.questCardTitle(),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryLight,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            ThematicTextsCatalog.questCardSubtitle(),
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildProgressRow(context, ref, quest),
        ],
      ),
    );
  }

  Widget _buildProgressRow(
    BuildContext context,
    WidgetRef ref,
    QuestState quest,
  ) {
    final completed = quest.completedToday;
    const required = QuestCalculator.requiredCompletions;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ThematicTextsCatalog.questProgressLabel(completed),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (completed / required).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: AppColors.surfaceLight,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.success,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        _buildAction(context, ref, quest),
      ],
    );
  }

  Widget _buildAction(BuildContext context, WidgetRef ref, QuestState quest) {
    if (quest.isClaimed) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: AppColors.success, size: 18),
          SizedBox(width: 6),
          Text(
            'Reclamada',
            style: TextStyle(fontSize: 12, color: AppColors.success),
          ),
        ],
      );
    }

    if (quest.canClaim) {
      return FilledButton(
        onPressed: () => _claim(context, ref),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        child: Text(
          ThematicTextsCatalog.questClaimButtonLabel(),
          style: const TextStyle(color: Colors.white),
        ),
      );
    }

    return const Text(
      'En progreso',
      style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
    );
  }

  Future<void> _claim(BuildContext context, WidgetRef ref) async {
    final levelUp = await ref.read(questProvider.notifier).claim();
    if (levelUp != null && context.mounted) {
      showLevelUpSnackBar(context, levelUp);
    }
  }
}