import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:slate_app/domain/enums/badge_type.dart';
import 'package:slate_app/presentation/screens/stats/widgets/badge_presentation.dart';

void main() {
  group('BadgePresentation.resolveIconData', () {
    test(
        'usa los iconos actuales SL (flame/emoji_events/military_tech disponibles)',
        () {
      expect(
        BadgePresentation.resolveIconData(type: BadgeType.streak7),
        Icons.whatshot,
        reason: 'streak7 usa el icono flame',
      );
      expect(
        BadgePresentation.resolveIconData(type: BadgeType.streak60),
        Icons.emoji_events,
        reason: 'streak60 usa el icono emoji_events',
      );
      expect(
        BadgePresentation.resolveIconData(type: BadgeType.streak30),
        Icons.military_tech,
        reason: 'streak30 usa el icono military_tech',
      );
    });

    test('iconDataFor: desconocido cae a star', () {
      expect(BadgePresentation.iconDataFor('no-existe'), Icons.star);
      expect(BadgePresentation.iconDataFor('moon'), Icons.nightlight_round);
    });
  });
}