enum BadgeType {
  streak3,
  streak7,
  streak14,
  streak21,
  streak30,
  streak60,
  streak90,
  streak180,
  streak365;

  int get requiredDays {
    switch (this) {
      case BadgeType.streak3:
        return 3;
      case BadgeType.streak7:
        return 7;
      case BadgeType.streak14:
        return 14;
      case BadgeType.streak21:
        return 21;
      case BadgeType.streak30:
        return 30;
      case BadgeType.streak60:
        return 60;
      case BadgeType.streak90:
        return 90;
      case BadgeType.streak180:
        return 180;
      case BadgeType.streak365:
        return 365;
    }
  }

  String get name {
    switch (this) {
      case BadgeType.streak3:
        return 'Primer Paso';
      case BadgeType.streak7:
        return 'Semana Perfecta';
      case BadgeType.streak14:
        return 'Quincena';
      case BadgeType.streak21:
        return 'Hábito Formado';
      case BadgeType.streak30:
        return 'Mes de Hierro';
      case BadgeType.streak60:
        return 'Doble Mes';
      case BadgeType.streak90:
        return 'Trimestre';
      case BadgeType.streak180:
        return 'Medio Año';
      case BadgeType.streak365:
        return 'Leyenda';
    }
  }

  String get iconName {
    switch (this) {
      case BadgeType.streak3:
        return 'eye';
      case BadgeType.streak7:
        return 'flame';
      case BadgeType.streak14:
        return 'sword';
      case BadgeType.streak21:
        return 'shield';
      case BadgeType.streak30:
        return 'military_tech';
      case BadgeType.streak60:
        return 'emoji_events';
      case BadgeType.streak90:
        return 'workspace_premium';
      case BadgeType.streak180:
        return 'diamond';
      case BadgeType.streak365:
        return 'skull';
    }
  }

  /// Devuelve todas las insignias cuyo umbral es menor o igual a [days].
  ///
  /// Permite desbloquear de una sola vez TODOS los hitos alcanzados cuando la
  /// racha sube más de un día de golpe (p. ej. un backfill de historial):
  /// `badgesUpTo(14)` devuelve streak3, streak7 y streak14.
  static List<BadgeType> badgesUpTo(int days) {
    return BadgeType.values.where((b) => b.requiredDays <= days).toList();
  }
}