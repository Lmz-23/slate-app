import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:slate_app/domain/enums/badge_type.dart';
import 'package:slate_app/presentation/screens/stats/widgets/badge_presentation.dart';

void main() {
  group('BadgePresentation.resolveName', () {
    test('usa la subnomenclatura Slate System (fuente única)', () {
      expect(
        BadgePresentation.resolveName(type: BadgeType.streak3),
        'Rango E · Nivel I',
      );
      expect(
        BadgePresentation.resolveName(type: BadgeType.streak14),
        'Rango D · Nivel I',
      );
      expect(
        BadgePresentation.resolveName(type: BadgeType.streak180),
        'Rango S · Nivel I',
      );
      expect(
        BadgePresentation.resolveName(type: BadgeType.streak365),
        'Nivel Nacional',
      );
    });

    test('resolveFlavor siempre devuelve el apodo (nunca null)', () {
      expect(
        BadgePresentation.resolveFlavor(type: BadgeType.streak3),
        'Cazador Novato',
      );
      expect(
        BadgePresentation.resolveFlavor(type: BadgeType.streak7),
        'Semana Perfecta',
      );
    });
  });

  group('BadgePresentation.resolveIconData', () {
    test('usa los iconos sugeridos SL (moon/medal/sword/award disponibles)',
        () {
      expect(
        BadgePresentation.resolveIconData(type: BadgeType.streak7),
        Icons.nightlight_round,
        reason: 'streak7 usa el icono moon',
      );
      expect(
        BadgePresentation.resolveIconData(type: BadgeType.streak60),
        Icons.military_tech,
        reason: 'streak60 usa el icono medal',
      );
      expect(
        BadgePresentation.resolveIconData(type: BadgeType.streak30),
        Icons.verified,
        reason: 'streak30 usa el icono award',
      );
    });

    test('iconDataFor: desconocido cae a star', () {
      expect(BadgePresentation.iconDataFor('no-existe'), Icons.star);
      expect(BadgePresentation.iconDataFor('moon'), Icons.nightlight_round);
    });
  });
}