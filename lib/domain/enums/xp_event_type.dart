/// Tipo de evento que genera (o revierte) XP del Jugador.
///
/// F2: hoy solo se disparan eventos de TAREA (al completar/desmarcar una
/// misión). El modelo se diseña desde ya para admitir eventos de SUBTAREA en
/// F4 (`subtask`): los métodos del notifier están separados por evento, de modo
/// que añadir subtareas no requiere cambiar la curva ni la persistencia.
enum XpEventType {
  /// XP de una tarea (misión) completada/desmarcada. +10/+15/+20 según
  /// prioridad.
  task,

  /// XP de una subtarea completada/desmarcada (F4). +2 por subtarea.
  subtask,
}