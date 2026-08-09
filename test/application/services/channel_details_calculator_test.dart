import 'package:flutter_test/flutter_test.dart';

import 'package:slate_app/application/services/channel_details_calculator.dart';
import 'package:slate_app/domain/entities/user_settings.dart';

/// Lógica PURA de derivación del canal `task_reminders` desde los ajustes del
/// usuario (Mejora 2: sonido/vibración/badge).
void main() {
  group('channelDetailsFromSettings (derivación del canal)', () {
    test('por defecto (todo activo): sonido, vibración y badge', () {
      final channel =
          ReminderChannelSettingsCalculator.fromSettings(const UserSettings());

      expect(channel.playSound, isTrue);
      expect(channel.enableVibration, isTrue);
      expect(channel.showBadge, isTrue);
      expect(channel.presentSound, isTrue);
      expect(channel.presentBadge, isTrue);
    });

    test('notificationSound=false -> recordatorio SILENCIOSO sin tocar vibración',
        () {
      final settings =
          const UserSettings(notificationSound: false, notificationVibration: true);

      final channel =
          ReminderChannelSettingsCalculator.fromSettings(settings);

      expect(channel.playSound, isFalse);
      expect(channel.enableVibration, isTrue);
      expect(channel.showBadge, isTrue);
      // iOS sigue el toggle de sonido; vibración no existe como control propio.
      expect(channel.presentSound, isFalse);
    });

    test('notificationVibration=false -> sin vibración Y sin sonido (regla Android)',
        () {
      // El usuario mantiene el sonido activo, pero en Android desactivar la
      // vibración del canal también desactiva su sonido (comportamiento del
      // sistema, documentado en Mejora 2).
      final channel = ReminderChannelSettingsCalculator.fromSettings(
        const UserSettings(notificationSound: true, notificationVibration: false),
      );

      expect(channel.enableVibration, isFalse);
      expect(channel.playSound, isFalse, reason: 'Android: sin vibración no hay sonido');
      // En iOS no hay vibración separable: el sonido respeta el toggle de sonido.
      expect(channel.presentSound, isTrue);
    });

    test('sonido y vibración desactivados: ambos a false', () {
      final channel = ReminderChannelSettingsCalculator.fromSettings(
        const UserSettings(notificationSound: false, notificationVibration: false),
      );

      expect(channel.playSound, isFalse);
      expect(channel.enableVibration, isFalse);
    });

    test('notificationBadge=false -> showBadge/presentBadge a false', () {
      final channel = ReminderChannelSettingsCalculator.fromSettings(
        const UserSettings(
          notificationSound: true,
          notificationVibration: true,
          notificationBadge: false,
        ),
      );

      expect(channel.showBadge, isFalse);
      expect(channel.presentBadge, isFalse);
      expect(channel.playSound, isTrue);
      expect(channel.enableVibration, isTrue);
    });

    test('combinación: sonido off + vibración off + badge off -> todo silenciado',
        () {
      final channel = ReminderChannelSettingsCalculator.fromSettings(
        const UserSettings(
          notificationSound: false,
          notificationVibration: false,
          notificationBadge: false,
        ),
      );

      expect(channel.playSound, isFalse);
      expect(channel.enableVibration, isFalse);
      expect(channel.showBadge, isFalse);
      expect(channel.presentSound, isFalse);
      expect(channel.presentBadge, isFalse);
    });
  });
}