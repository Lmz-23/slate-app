import 'package:flutter/material.dart';

import '../../../../application/services/thematic_texts_catalog.dart';
import '../../../../domain/enums/badge_type.dart';

/// Resolución CENTRALIZADA de nombre/icono de las insignias para la vitrina
/// ([BadgeVault]) y otros consumidores de presentación.
///
/// La estética "Slate System" es la ÚNICA identidad del producto: la
/// subnomenclatura de rangos/niveles del [ThematicTextsCatalog] se usa
/// siempre, sin depender de ningún ajuste del usuario. Ya no existe resolución
/// canónica ni configuración IA personalizada por usuario.
class BadgePresentation {
  const BadgePresentation._();

  /// Nombre mostrado: rango/nivel SL del hito (fuente única).
  static String resolveName({required BadgeType type}) =>
      ThematicTextsCatalog.slateBadgeTitle(type);

  /// Apodo SL ("Cazador Novato", ...) — SIEMPRE disponible.
  static String resolveFlavor({required BadgeType type}) =>
      ThematicTextsCatalog.slateBadgeFlavor(type);

  /// Nombre del icono sugerido para el hito (fuente única).
  static String resolveIconName({required BadgeType type}) =>
      ThematicTextsCatalog.slateBadgeIconName(type);

  /// [IconData] del icono resuelto.
  static IconData resolveIconData({required BadgeType type}) =>
      iconDataFor(resolveIconName(type: type));

  /// Mapa de iconos (incluye los sugeridos para SL: moon/medal/sword/award y
  /// los usados por la IA) con fallback a `Icons.star`.
  static IconData iconDataFor(String iconName) {
    const iconMap = {
      'star': Icons.star,
      'fire': Icons.local_fire_department,
      'lightning': Icons.bolt,
      'flower': Icons.local_florist,
      'shield': Icons.shield,
      'trophy': Icons.emoji_events,
      'crown': Icons.workspace_premium,
      'diamond': Icons.diamond,
      'rocket': Icons.rocket_launch,
      'sword': Icons.sports_martial_arts,
      'medal': Icons.military_tech,
      'award': Icons.verified,
      'moon': Icons.nightlight_round,
      'flame': Icons.whatshot,
      'bolt': Icons.bolt,
      'zap': Icons.flash_on,
      'sun': Icons.wb_sunny,
      'heart': Icons.favorite,
      'bell': Icons.notifications,
      'bellSlash': Icons.notifications_off,
      'bellOff': Icons.notifications_off,
      'volume': Icons.volume_up,
      'volume2': Icons.volume_down,
      'volumeX': Icons.volume_off,
      'alarm': Icons.alarm,
      'clock': Icons.access_time,
      'hourglass': Icons.hourglass_empty,
    };
    return iconMap[iconName] ?? Icons.star;
  }
}