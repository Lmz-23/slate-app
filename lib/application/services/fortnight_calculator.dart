import '../../domain/entities/badge.dart';
import '../../domain/entities/task.dart';

/// Periodo quincenal: `[start, end]` inclusivos (días calendario).
class Fortnight {
  final DateTime start;
  final DateTime end;

  const Fortnight({required this.start, required this.end});

  /// ¿El instante [moment] cae dentro del periodo (año/mes/día)?
  bool contains(DateTime moment) {
    final day = DateTime(moment.year, moment.month, moment.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  /// Etiqueta legible del periodo, p. ej. `01/08 - 15/08`.
  String get label {
    final s = start;
    final e = end;
    return '${s.day.toString().padLeft(2, '0')}/'
        '${s.month.toString().padLeft(2, '0')} - '
        '${e.day.toString().padLeft(2, '0')}/'
        '${e.month.toString().padLeft(2, '0')}';
  }
}

/// Datos del resumen quincenal que reporta la notificación `0x60000005`
/// (F3, decisión D).
class FortnightSummaryStats {
  /// Periodo reportado (quincena recién terminada).
  final Fortnight period;

  /// Tareas completadas dentro de [period] (según `completedAt`).
  final int completedCount;

  /// Racha vigente al programar el resumen.
  final int currentStreak;

  /// Nivel de Jugador al programar el resumen.
  final int level;

  /// XP total del Jugador al programar el resumen.
  final int totalXp;

  /// Insignias desbloqueadas dentro de [period] (según `unlockedAt`).
  final int badgesUnlockedCount;

  const FortnightSummaryStats({
    required this.period,
    required this.completedCount,
    required this.currentStreak,
    required this.level,
    required this.totalXp,
    required this.badgesUnlockedCount,
  });
}

/// Lógica PURA del resumen quincenal del Sistema (F3, decisión D).
///
/// Cadencia QUINCENAL: días fijos **1 y 16** de cada mes a las [horas] 20:00.
/// Límites de las quincenas:
/// - quincena-1: del día 1 al 15 (ambos inclusive);
/// - quincena-2: del día 16 al último día del mes (ambos inclusive).
///
/// La notificación del día 16 reporta la quincena-1 de ese mes (1..15); la del
/// día 1 reporta la quincena-2 del mes ANTERIOR (16..fin de mes).
class FortnightCalculator {
  const FortnightCalculator._();

  /// Día que inicia la quincena-2 (16 del mes). La quincena-1 empieza el 1.
  static const int secondHalfStartDay = 16;

  /// Último día del mes: `DateTime(year, month+1, 0)` es el día 0 del mes
  /// siguiente, es decir, el último día de [month].
  static DateTime lastDayOfMonth(int year, int month) =>
      DateTime(year, month + 1, 0);

  /// Quincena que CONTIENE el día [day]: 1..15 (quincena-1) o 16..fin de mes
  /// (quincena-2). Las horas de [day] se ignoran.
  static Fortnight periodForDate(DateTime day) {
    if (day.day < secondHalfStartDay) {
      return Fortnight(
        start: DateTime(day.year, day.month, 1),
        end: DateTime(day.year, day.month, 15),
      );
    }
    return Fortnight(
      start: DateTime(day.year, day.month, secondHalfStartDay),
      end: lastDayOfMonth(day.year, day.month),
    );
  }

  /// Próximo disparo del resumen quincenal ([hour]:00 del día 1 o 16),
  /// estrictamente posterior a [now] (patrón Fix A: nunca programar al pasado).
  ///
  /// Casos:
  /// - antes de las 20:00 del día 1 → HOY a las 20:00 (reporta la quincena-2
  ///   del mes anterior);
  /// - resto del 1..16 antes de las 20:00 → día 16 a las 20:00 (reporta la
  ///   quincena-1 de este mes);
  /// - después de las 20:00 del 16 → día 1 del mes siguiente a las 20:00
  ///   (reporta la quincena-2 de este mes).
  static DateTime nextFireTime(DateTime now, {required int hour}) {
    final firstThisMonth = DateTime(now.year, now.month, 1, hour, 0);
    if (firstThisMonth.isAfter(now)) return firstThisMonth;

    final sixteenthThisMonth = DateTime(now.year, now.month, 16, hour, 0);
    if (sixteenthThisMonth.isAfter(now)) return sixteenthThisMonth;

    final nextMonth = now.month == 12 ? 1 : now.month + 1;
    final nextYear = now.month == 12 ? now.year + 1 : now.year;
    return DateTime(nextYear, nextMonth, 1, hour, 0);
  }

  /// Periodo que REPORTARÁ la notificación programada en [fireTime].
  ///
  /// El disparo del día 16 reporta la quincena-1 de ese mes (1..15); el del
  /// día 1 reporta la quincena-2 del mes ANTERIOR (16..fin de mes).
  static Fortnight periodForFireTime(DateTime fireTime) {
    if (fireTime.day == secondHalfStartDay) {
      return Fortnight(
        start: DateTime(fireTime.year, fireTime.month, 1),
        end: DateTime(fireTime.year, fireTime.month, 15),
      );
    }
    final prevMonth = fireTime.month == 1 ? 12 : fireTime.month - 1;
    final prevYear = fireTime.month == 1 ? fireTime.year - 1 : fireTime.year;
    return Fortnight(
      start: DateTime(prevYear, prevMonth, secondHalfStartDay),
      end: lastDayOfMonth(prevYear, prevMonth),
    );
  }

  /// Tareas completadas dentro de [period] (según `Task.completedAt`).
  ///
  /// F4-fix H2 (regla de producto): las SUBTAREAS no cuentan como tareas para
  /// el resumen quincenal; solo las tareas con `isSubtask == false`.
  static int completedCountIn(List<Task> tasks, Fortnight period) => tasks
      .where((t) =>
          !t.isSubtask &&
          t.isCompleted &&
          t.completedAt != null &&
          period.contains(t.completedAt!))
      .length;

  /// Insignias desbloqueadas dentro de [period] (según `Badge.unlockedAt`).
  static int badgesUnlockedIn(List<Badge> badges, Fortnight period) =>
      badges.where((b) => period.contains(b.unlockedAt)).length;

  /// Cuerpo CANÓNICO (tema OFF) del resumen quincenal.
  static String fortnightBody(FortnightSummaryStats stats) {
    var body = 'Quincena ${stats.period.label}: '
        '${stats.completedCount} tarea${stats.completedCount == 1 ? '' : 's'} '
        'completada${stats.completedCount == 1 ? '' : 's'}.';
    if (stats.currentStreak > 0) {
      body += ' Racha actual: ${stats.currentStreak} '
          'día${stats.currentStreak == 1 ? '' : 's'}.';
    }
    body += ' Nivel ${stats.level} · ${stats.totalXp} XP. '
        'Insignias desbloqueadas: ${stats.badgesUnlockedCount}.';
    return body;
  }
}