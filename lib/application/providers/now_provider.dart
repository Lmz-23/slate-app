import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/timezone_service.dart';
import 'settings_provider.dart';

/// Proveedor del instante actual en la zona horaria configurada por el usuario.
///
/// Emite de inmediato el instante actual y lo refresca cada 30 segundos, de
/// forma que "hoy", las rachas y el calendario mensual no queden obsoletos
/// mientras la app permanece abierta (incluso sin cambiar de ajustes).
///
/// Los consumidores deben usar `ref.watch(nowProvider).value ?? DateTime.now()`
/// para obtener el `DateTime` más reciente con un respaldo en caso de que el
/// stream aún no haya emitido.
final nowProvider = StreamProvider<DateTime>((ref) {
  final settings = ref.watch(settingsProvider);
  return Stream<DateTime>.multi((controller) {
    controller.add(TimezoneService.nowInTimezone(settings.timezone));
    final timer = Timer.periodic(const Duration(seconds: 30), (_) {
      controller.add(TimezoneService.nowInTimezone(settings.timezone));
    });
    controller.onCancel = timer.cancel;
  });
});
