/// Identificadores estables de notificaciones.
///
/// Android exige que el `id` de una notificación sea un entero (int32) y que
/// no cambie entre programaciones-cancelaciones de la misma notificación. Por
/// eso los ids se DERIVAN de forma determinista del id de la entidad y nunca
/// de un valor aleatorio.
///
/// Se usan rangos separados para eliminar colisiones:
///   - Recordatorios de tarea: `[0x10000000, 0x4FFFFFFF]` (30 bits derivados
///     del id de la tarea).
///   - Recordatorios diarios: `0x60000001` (resumen de la mañana),
///     `0x60000002` (resumen de la tarde) y `0x60000003` (cierre de jornada).
library;

/// FNV-1a de 32 bits. Determinista, rápido y estable entre ejecuciones de la
/// misma versión de Dart (a diferencia de `String.hashCode`, que no garantiza
/// estabilidad entre versiones del runtime).
int _fnv1a32(String input) {
  var hash = 0x811c9dc5;
  for (final unit in input.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

/// Id determinista del recordatorio de la tarea [taskId].
///
/// Usa 30 bits del hash para mantener el resultado dentro del rango de
/// recordatorios de tareas y garantizar que nunca colisione con los ids de los
/// recordatorios diarios (0x60000001/0x60000002).
int reminderIdForTask(String taskId) =>
    0x10000000 + (_fnv1a32('task:$taskId') & 0x3FFFFFFF);

/// Id del recordatorio diario de resumen de la mañana (10:00 por defecto).
const int morningDailyReminderId = 0x60000001;

/// Id del recordatorio diario de resumen de la tarde (19:00 por defecto).
const int eveningDailyReminderId = 0x60000002;

/// Id del recordatorio diario de cierre de jornada (quest complete diaria).
///
/// Se programa al cruzar de día usando `dayResetHour` (default 04:00): dispara
/// a la hora de reset del día siguiente y reporta el resultado del día que
/// acaba de cerrar.
const int dayClosureReminderId = 0x60000003;