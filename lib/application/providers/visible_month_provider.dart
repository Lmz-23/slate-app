import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'now_provider.dart';

/// Proveedor del mes visible en la pantalla de Estadísticas.
///
/// El estado es el PRIMER DÍA del mes visible (`DateTime(año, mes)`), de modo
/// que año y mes quedan normalizados (día = 1, hora = 00:00) y las
/// comparaciones de mes son exactas.
///
/// Se inicializa con el mes en curso leído desde [nowProvider] (con respaldo a
/// `DateTime.now()`). Al ser un proveedor global no auto-disposable del
/// `ProviderScope` raíz, el mes visible se CONSERVA al cambiar de pestaña y
/// solo se reinicia si se pulsa "Hoy" o si la app se relanza. Este
/// comportamiento es coherente con `selectedDateProvider` de la pantalla
/// Semana.
///
/// Límites de navegación (decisión de producto C1a):
/// - Hacia atrás: libre (sin límite).
/// - Hacia adelante: limitado al mes en curso (no se puede ir más allá).
class VisibleMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    return _currentMonth;
  }

  /// Primer día del mes en curso según [nowProvider].
  DateTime get _currentMonth {
    final now = ref.read(nowProvider).value ?? DateTime.now();
    return DateTime(now.year, now.month);
  }

  /// `true` si se permite avanzar al mes siguiente, es decir, si el mes
  /// siguiente NO está después del mes en curso (C1a).
  bool get canGoToNextMonth {
    final next = DateTime(state.year, state.month + 1);
    return !next.isAfter(_currentMonth);
  }

  /// Navega al mes anterior. Siempre permitido (C1a).
  void goToPreviousMonth() {
    state = DateTime(state.year, state.month - 1);
  }

  /// Navega al mes siguiente si no supera el mes en curso (C1a).
  ///
  /// Si el mes siguiente queda más allá del mes actual, la operación se
  /// ignora (no lanza error ni cambia el estado).
  void goToNextMonth() {
    if (!canGoToNextMonth) return;
    state = DateTime(state.year, state.month + 1);
  }

  /// Vuelve al mes en curso (decisión de producto C3a).
  void goToToday() {
    state = _currentMonth;
  }
}

final visibleMonthProvider =
    NotifierProvider<VisibleMonthNotifier, DateTime>(VisibleMonthNotifier.new);
