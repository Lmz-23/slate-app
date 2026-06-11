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
        return 'star';
      case BadgeType.streak7:
        return 'fire';
      case BadgeType.streak14:
        return 'lightning';
      case BadgeType.streak21:
        return 'flower';
      case BadgeType.streak30:
        return 'shield';
      case BadgeType.streak60:
        return 'trophy';
      case BadgeType.streak90:
        return 'crown';
      case BadgeType.streak180:
        return 'diamond';
      case BadgeType.streak365:
        return 'rocket';
    }
  }

  static BadgeType? fromDays(int days) {
    for (final badge in BadgeType.values) {
      if (badge.requiredDays == days) return badge;
    }
    return null;
  }
}