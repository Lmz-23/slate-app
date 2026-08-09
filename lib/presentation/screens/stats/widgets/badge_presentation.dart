import 'package:flutter/material.dart';

import '../../../../application/services/thematic_texts_catalog.dart';
import '../../../../domain/entities/user_settings.dart';
import '../../../../domain/enums/badge_type.dart';

/// Resolución CENTRALIZADA de nombre/icono de las insignias para la vitrina
/// ([BadgeVault]) y otros consumidores de presentación.
///
/// Orden de resolución (persistente a nivel de presentación):
/// 1. Configuración IA personalizada del usuario (`customBadgeConfigs`).
/// 2. Subnomenclatura Slate System (rangos/niveles) si el tema está ON.
/// 3. Nombre/icono canónico (comportamiento actual, fallback por defecto).
///
/// Con el tema OFF (default) la resolución devuelve exactamente los nombres e
/// iconos canónicos, por lo que los tests existentes de la vitrina siguen
/// pasando sin cambios.
class BadgePresentation {
  const BadgePresentation._();

  /// Nombre interno del enum (`BadgeType.streak7` → `'streak7'`).
  ///
  /// No se usa `type.name`: ese getter está sobreescrito en [BadgeType] para
  /// devolver el nombre CANÓNICO ("Semana Perfecta"), mientras que las
  /// configuraciones IA se guardan con la clave del enum ("streak7").
  static String _badgeTypeKey(BadgeType type) =>
      type.toString().split('.').last;

  static CustomBadgeConfig? _customFor(
    BadgeType type,
    List<CustomBadgeConfig> configs,
  ) {
    final key = _badgeTypeKey(type);
    for (final config in configs) {
      if (config.badgeType == key) return config;
    }
    return null;
  }

  /// Nombre mostrado: config IA → rango SL (tema ON) → canónico.
  static String resolveName({
    required BadgeType type,
    required UserSettings settings,
  }) {
    final custom = _customFor(type, settings.customBadgeConfigs);
    if (custom != null) return custom.customName;
    if (settings.slateSystemTheme) {
      return ThematicTextsCatalog.slateBadgeTitle(type);
    }
    return type.name;
  }

  /// Apodo SL ("Cazador Novato", ...) o `null` si el tema está OFF.
  static String? resolveFlavor({
    required BadgeType type,
    required UserSettings settings,
  }) {
    if (!settings.slateSystemTheme) return null;
    return ThematicTextsCatalog.slateBadgeFlavor(type);
  }

  /// Icono (nombre): config IA → icono sugerido SL (tema ON) → canónico.
  static String resolveIconName({
    required BadgeType type,
    required UserSettings settings,
  }) {
    final custom = _customFor(type, settings.customBadgeConfigs);
    if (custom != null) return custom.iconName;
    if (settings.slateSystemTheme) {
      return ThematicTextsCatalog.slateBadgeIconName(type);
    }
    return type.iconName;
  }

  /// [IconData] del icono resuelto.
  static IconData resolveIconData({
    required BadgeType type,
    required UserSettings settings,
  }) =>
      iconDataFor(resolveIconName(type: type, settings: settings));

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