import 'dart:math' as math;

import '../../domain/enums/recurrence_type.dart';

/// Lógica PURA de generación de fechas de recurrencia.
///
/// Extraída de `TasksNotifier._generateRecurringTasks` (Addendum 2, A12) para
/// que el generador de ocurrencias (`horizonte 365`) y el detector de
/// solapamiento (`horizonte 35`) compartan EXACTAMENTE la misma regla. Si
/// divergieran, el detector podría aprobar un guardado que el generador
/// terminaría materializando en conflicto (RG20).
///
/// Preserva la semántica exacta del bucle original: ancla mensual con recorte
/// al último día del mes, y `% 7` para días específicos.
class RecurrenceCalculator {
  const RecurrenceCalculator._();

  /// Fechas de las ocurrencias de una serie que comienza en [base], sin
  /// incluir [base] misma, proyectando [days] días hacia adelante.
  ///
  /// Devuelve una lista vacía si [recurrence] es [RecurrenceType.none].
  static List<DateTime> occurrenceDates({
    required DateTime base,
    required RecurrenceType recurrence,
    List<int>? recurrenceDays,
    required int days,
  }) {
    if (recurrence == RecurrenceType.none) return const [];

    final dates = <DateTime>[];
    DateTime nextDate = base.add(const Duration(days: 1));

    for (int i = 0; i < days; i++) {
      bool shouldGenerate = false;

      switch (recurrence) {
        case RecurrenceType.daily:
          shouldGenerate = true;
          break;
        case RecurrenceType.weekly:
          if (nextDate.weekday == base.weekday) {
            shouldGenerate = true;
          }
          break;
        case RecurrenceType.specificDays:
          if (recurrenceDays != null &&
              recurrenceDays.contains(nextDate.weekday % 7)) {
            shouldGenerate = true;
          }
          break;
        case RecurrenceType.monthly:
          final anchorDay = math.min(
            base.day,
            DateTime(nextDate.year, nextDate.month + 1, 0).day,
          );
          if (nextDate.day == anchorDay) {
            shouldGenerate = true;
          }
          break;
        case RecurrenceType.none:
          break;
      }

      if (shouldGenerate) {
        dates.add(nextDate);
      }
      nextDate = nextDate.add(const Duration(days: 1));
    }

    return dates;
  }
}
