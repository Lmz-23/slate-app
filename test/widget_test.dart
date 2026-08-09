import 'package:flutter_test/flutter_test.dart';

import 'package:slate_app/application/services/timezone_service.dart';
import 'package:slate_app/core/extensions/datetime_extensions.dart';

void main() {
  group('DateTimeExtensions.relativeDay', () {
    test('devuelve "Hoy" para la misma fecha', () {
      final now = DateTime(2026, 1, 15, 10, 30);
      final date = DateTime(2026, 1, 15);
      expect(date.relativeDay(now: now), 'Hoy');
    });

    test('devuelve "Mañana" para el día siguiente', () {
      final now = DateTime(2026, 1, 15, 10, 30);
      final date = DateTime(2026, 1, 16);
      expect(date.relativeDay(now: now), 'Mañana');
    });

    test('devuelve "Ayer" para el día anterior', () {
      final now = DateTime(2026, 1, 15, 10, 30);
      final date = DateTime(2026, 1, 14);
      expect(date.relativeDay(now: now), 'Ayer');
    });

    test('devuelve la fecha formateada para fechas lejanas', () {
      final now = DateTime(2026, 1, 15, 10, 30);
      final date = DateTime(2026, 2, 1);
      expect(date.relativeDay(now: now), '01 Feb 2026');
    });
  });

  group('TimezoneService.nowInTimezone', () {
    test('devuelve un DateTime para una zona válida', () {
      final now = TimezoneService.nowInTimezone('America/Bogota');
      expect(now, isA<DateTime>());
    });

    test('cae a DateTime.now() para una zona desconocida', () {
      final now = TimezoneService.nowInTimezone('Invalid/Zone');
      expect(now, isA<DateTime>());
      final fallback = DateTime.now();
      expect(now.year, fallback.year);
      expect(now.month, fallback.month);
      expect(now.day, fallback.day);
    });
  });
}
