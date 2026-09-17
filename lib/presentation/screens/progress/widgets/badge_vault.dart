import 'package:flutter/material.dart' hide Badge;

import '../../../../core/theme/slate_shapes.dart';
import '../../../../core/theme/slate_theme_context.dart';
import '../../../../domain/entities/badge.dart';
import '../../../../domain/enums/badge_type.dart';
import 'badge_presentation.dart';

/// Bloque "Insignias" de `/progress` (sistema-visual-fase3.md §1/§2.7): grid
/// de tiles circulares de 56px, 4 columnas.
///
/// Restilizado (Parte C, punto 8): insignia bloqueada usa contorno `outline`
/// (silueta monocroma), NUNCA baja opacidad — un contorno limpio comunica
/// "aún no" sin verse "sucio" sobre fondos claros cálidos.
class BadgeVault extends StatelessWidget {
  final List<Badge> badges;

  const BadgeVault({
    super.key,
    required this.badges,
  });

  @override
  Widget build(BuildContext context) {
    final slate = context.slate;
    const allBadgeTypes = BadgeType.values;
    final unlockedIds = badges.map((b) => b.type).toSet();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: slate.surface,
        borderRadius: BorderRadius.circular(SlateShapes.radiusLarge),
        boxShadow: context.slateShapes.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vitrina de insignias',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: slate.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              // Altura fija (no `childAspectRatio`): el contenido de cada
              // celda (círculo 56px + hasta 2 líneas de nombre + subtítulo)
              // tiene una altura constante en px independiente del ancho de
              // pantalla. Con `childAspectRatio` la altura escalaba con el
              // ancho de la celda, por lo que en teléfonos angostos la celda
              // quedaba más baja que el contenido y producía overflow
              // vertical (detectado en verificación visual: "BOTTOM
              // OVERFLOWED BY 9.0 PIXELS").
              mainAxisExtent: 118,
            ),
            itemCount: allBadgeTypes.length,
            itemBuilder: (context, index) {
              final badgeType = allBadgeTypes[index];
              final isUnlocked = unlockedIds.contains(badgeType);
              final badge = isUnlocked
                  ? badges.firstWhere((b) => b.type == badgeType)
                  : null;

              return _buildBadgeItem(context, badgeType, isUnlocked, badge);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeItem(
    BuildContext context,
    BadgeType type,
    bool isUnlocked,
    Badge? badge,
  ) {
    final slate = context.slate;
    // Resolución centralizada (Slate System es la única identidad del producto).
    final displayName = BadgePresentation.resolveName(type: type);
    final flavor = BadgePresentation.resolveFlavor(type: type);
    final iconData = BadgePresentation.resolveIconData(type: type);

    final subtitle = '$flavor · ${type.requiredDays} días';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: slate.surface,
            shape: BoxShape.circle,
            border: isUnlocked ? null : Border.all(color: slate.outline, width: 1.5),
            boxShadow: isUnlocked ? context.slateShapes.tileShadow : null,
          ),
          child: Icon(
            iconData,
            size: 28,
            color: isUnlocked ? slate.accent : slate.outline,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isUnlocked ? displayName : '???',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: slate.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            color: slate.textTertiary,
          ),
        ),
      ],
    );
  }
}
