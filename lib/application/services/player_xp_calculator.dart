import 'dart:math' as math;

import '../../domain/enums/player_rank.dart';
import '../../domain/enums/task_priority.dart';

/// Lógica PURA (sin Hive ni Riverpod) del sistema de XP / Nivel de Jugador.
///
/// Decisiones de producto (F2, decisión A):
/// - XP por tarea según prioridad: +10 baja · +15 media · +20 alta.
/// - Desmarcar una tarea RESTA el XP ganado (simetría anti-exploit).
/// - Curva de niveles: `100 · (nivel−1)²` XP totales. Nivel 2: 100 XP
///   totales; nivel 3: 400; nivel 4: 900; nivel 5: 1600...
/// - Nivel/XP IRREVERSIBLE: el nivel alcanzado nunca baja aunque el XP total
///   se reduzca al desmarcar tareas. El tope del nivel se mantiene.
/// - Backfill: usuarios existentes parten de nivel 1 con 0 XP.
/// - Rango E→S por tramos de nivel: 1-9 E, 10-19 D, 20-29 C, 30-49 B, 50-69 A,
///   70+ S.
class PlayerXpCalculator {
  const PlayerXpCalculator._();

  /// XP ganado al completar una tarea según su prioridad (decisión A).
  static int xpForPriority(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.normal:
        return 10; // baja
      case TaskPriority.medium:
        return 15; // media
      case TaskPriority.high:
        return 20; // alta
    }
  }

  /// XP ganado al completar una SUBTAREA (F4). El modelo ya lo admite a
  /// través de `XpEventType.subtask`; todavía no existe UI de subtareas.
  static const int subtaskXp = 2;

  /// XP ganado al reclamar la quest diaria "Completa 3 tareas hoy" (F3,
  /// decisión C). Reclamable UNA vez por día y con acción explícita.
  static const int questXp = 25;

/// Umbral de XP TOTAL necesaria para alcanzar [level].
///
/// Curva de producto: `xpRequerido(nivel) = 100 · nivel²` con los puntos
/// EXPLÍCITOS de la decisión A: Nivel 2 = 100 XP totales; nivel 3 = 400;
/// nivel 4 = 900; nivel 5 = 1600. Estos puntos corresponden a
/// `100 · (nivel−1)²`, que es la forma implementada.
/// El nivel 1 es el nivel BASE de arranque (backfill de 0 XP): su umbral es 0.
  static int xpRequiredForLevel(int level) =>
      level <= 1 ? 0 : 100 * (level - 1) * (level - 1);

  /// Nivel DERIVADO del XP total: el mayor `nivel` cuyo umbral es ≤ [totalXp],
  /// nunca menor que 1.
  ///
  /// Nota: el nivel PERSISTIDO ([PlayerProfile.level]) puede ser MAYOR que
  /// este valor porque es irreversible (cacheado); esta función se usa solo
  /// para calcular el techo al SUBIR XP.
  static int levelForXp(int totalXp) {
    if (totalXp < xpRequiredForLevel(2)) return 1;
    return math.sqrt(totalXp / 100).floor() + 1;
  }

  /// XP acumulado DENTRO del nivel actual (respecto al umbral del nivel).
  static int xpIntoLevel(int totalXp, int level) =>
      totalXp - xpRequiredForLevel(level);

  /// Tamaño del tramo del nivel actual: XP necesario para pasar de [level] al
  /// siguiente. Siempre ≥ 100.
  static int xpSpanForLevel(int level) =>
      xpRequiredForLevel(level + 1) - xpRequiredForLevel(level);

  /// Progreso [0, 1] hacia el siguiente nivel. Lo usa la barra de XP de la
  /// tarjeta "Jugador".
  static double progressToNextLevel(int totalXp, int level) {
    final span = xpSpanForLevel(level);
    if (span <= 0) return 1.0;
    return (xpIntoLevel(totalXp, level) / span).clamp(0.0, 1.0);
  }

  /// Rango E→S del Jugador según el NIVEL (escalera de producto).
  static PlayerRank rankForLevel(int level) {
    if (level >= 70) return PlayerRank.s;
    if (level >= 50) return PlayerRank.a;
    if (level >= 30) return PlayerRank.b;
    if (level >= 20) return PlayerRank.c;
    if (level >= 10) return PlayerRank.d;
    return PlayerRank.e;
  }
}