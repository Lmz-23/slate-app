import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:slate_app/domain/entities/user_settings.dart';
import 'package:slate_app/domain/enums/badge_type.dart';
import 'package:slate_app/presentation/screens/stats/widgets/badge_presentation.dart';

void main() {
  group('BadgePresentation.resolveName', () {
    test('tema OFF (default): nombres canónicos actuales', () {
      expect(
        BadgePresentation.resolveName(
            type: BadgeType.streak3, settings: const UserSettings()),
        'Primer Paso',
      );
      expect(
        BadgePresentation.resolveName(
            type: BadgeType.streak365, settings: const UserSettings()),
        'Leyenda',
      );
    });

    test('tema ON: usa la subnomenclatura Slate System', () {
      const settings = UserSettings(slateSystemTheme: true);
      expect(
        BadgePresentation.resolveName(type: BadgeType.streak3, settings: settings),
        'Rango E · Nivel I',
      );
      expect(
        BadgePresentation.resolveName(type: BadgeType.streak180, settings: settings),
        'Rango S · Nivel I',
      );
      expect(
        BadgePresentation.resolveName(type: BadgeType.streak365, settings: settings),
        'Nivel Nacional',
      );
    });

    test('config personalizada IA gana sobre la nomenclatura SL', () {
      const settings = UserSettings(
        slateSystemTheme: true,
        customBadgeConfigs: [
          CustomBadgeConfig(
            badgeType: 'streak7',
            customName: 'Mi Semana',
            iconName: 'sword',
            daysRequired: 7,
          ),
        ],
      );
      expect(
        BadgePresentation.resolveName(type: BadgeType.streak7, settings: settings),
        'Mi Semana',
      );
      // El resto de hitos sin config siguen la nomenclatura SL.
      expect(
        BadgePresentation.resolveName(type: BadgeType.streak14, settings: settings),
        'Rango D · Nivel I',
      );
    });

    test('resolveFlavor: null con tema OFF, apodo con tema ON', () {
      expect(
        BadgePresentation.resolveFlavor(
            type: BadgeType.streak3, settings: const UserSettings()),
        isNull,
      );
      expect(
        BadgePresentation.resolveFlavor(
            type: BadgeType.streak3,
            settings: const UserSettings(slateSystemTheme: true)),
        'Cazador Novato',
      );
    });
  });

  group('BadgePresentation.resolveIconData', () {
    test('tema OFF: iconos canónicos', () {
      expect(
        BadgePresentation.resolveIconData(
            type: BadgeType.streak30, settings: const UserSettings()),
        Icons.shield,
      );
    });

    test('tema ON: iconos sugeridos SL (moon/medal/sword/award disponibles)',
        () {
      const settings = UserSettings(slateSystemTheme: true);
      expect(
        BadgePresentation.resolveIconData(type: BadgeType.streak7, settings: settings),
        Icons.nightlight_round,
        reason: 'streak7 usa el icono moon',
      );
      expect(
        BadgePresentation.resolveIconData(type: BadgeType.streak60, settings: settings),
        Icons.military_tech,
        reason: 'streak60 usa el icono medal',
      );
    });

    test('config personalizada IA gana sobre el icono SL', () {
      const settings = UserSettings(
        slateSystemTheme: true,
        customBadgeConfigs: [
          CustomBadgeConfig(
            badgeType: 'streak90',
            customName: 'Élite',
            iconName: 'award',
            daysRequired: 90,
          ),
        ],
      );
      expect(
        BadgePresentation.resolveIconData(type: BadgeType.streak90, settings: settings),
        Icons.verified,
      );
    });

    test('iconDataFor: desconocido cae a star', () {
      expect(BadgePresentation.iconDataFor('no-existe'), Icons.star);
      expect(BadgePresentation.iconDataFor('moon'), Icons.nightlight_round);
    });
  });
}