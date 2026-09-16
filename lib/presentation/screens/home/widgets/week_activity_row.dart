import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/providers/week_activity_provider.dart';
import '../../../../core/theme/slate_theme_context.dart';

/// 7 indicadores circulares de actividad semanal (L→D),
/// [weekActivityProvider]. Semánticamente distinto del bloque semanal de
/// Progreso (binario activo/inactivo aquí, porcentaje por día allá — A10).
class WeekActivityRow extends ConsumerWidget {
  const WeekActivityRow({super.key});

  static const _labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeDays = ref.watch(weekActivityProvider);
    final slate = context.slate;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final active = activeDays[i];
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? slate.success : Colors.transparent,
                border: Border.all(
                  color: active ? slate.success : slate.outline,
                  width: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _labels[i],
              style: TextStyle(fontSize: 10, color: slate.textTertiary),
            ),
          ],
        );
      }),
    );
  }
}
