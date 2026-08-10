import '../../data/hive/boxes/thematic_text_cache_box.dart';
import '../../domain/entities/task.dart';
import 'reminder_schedule_calculator.dart';
import 'thematic_texts_catalog.dart';

/// Resuelve el texto de una notificación en la identidad única "Slate System".
///
/// Orden de resolución (fuente única):
/// - Si existe variante generada con IA en [ThematicTextCache], se usa esa.
/// - Si no, se usa el catálogo local [ThematicTextsCatalog].
///
/// Contrato: SIEMPRE devuelve [ThematicText] (caché → catálogo). No existe
/// "tema OFF": la estética Sistema es la única identidad del producto.
///
/// DECISIÓN (review `3142d33`, Hallazgo 1 y 6): este resolver es de SOLO
/// LECTURA y NUNCA dispara la generación con IA.
///
/// - La generación con IA ocurre ÚNICAMENTE al GUARDAR una tarea o editar su
///   título ([TasksNotifier]), nunca en el path de programación de
///   notificaciones. Antes el resolver llamaba al generador de forma
///   incontrolada y, con tema ON + API key + toggle "Textos con IA" OFF, la
///   app invocaba a Gemini igualmente en cada ciclo de programación (violaba
///   el opt-in/privacidad del usuario). Desde este cambio es estructuralmente
///   imposible: el resolver no tiene referencia alguna al generador.
/// - Gating del opt-in de CONTENIDO: la generación exige
///   `useAIThematicTexts == true`, comprobado en el punto de guardado
///   (`TasksNotifier._maybeGenerateThematicVariants`). Con el toggle OFF la IA
///   NUNCA se invoca (verificado por test).
/// - Caché tras desactivar el toggle: las variantes CACHEADAS se siguen usando
///   aunque el usuario desactive "Textos con IA". Son datos locales ya
///   generados mientras el usuario tenía el opt-in activo; el toggle solo
///   detiene el ENVÍO de nuevos títulos al servicio externo. Se considera
///   defendible por privacidad (no se reenvía nada) y se documenta aquí como
///   decisión explícita.
///
/// Nunca lanza ni bloquea: la caché se lee de forma síncrona y siempre existe
/// un fallback local ([ThematicTextsCatalog]).
class ThematicTextsResolver {
  const ThematicTextsResolver({ThematicTextCache? cache}) : _cache = cache;

  final ThematicTextCache? _cache;

  ThematicText _fromCache(String key, ThematicText fallback) {
    final cached = _cache?.get(key);
    if (cached != null) {
      return ThematicText(title: cached.title, body: cached.body);
    }
    return fallback;
  }

  /// Recordatorio de tarea.
  ThematicText resolveTaskReminder(Task task) {
    return _fromCache(
      ThematicTextsCatalog.taskCacheKey(task),
      ThematicTextsCatalog.taskReminder(task),
    );
  }

  /// Resumen de la mañana (10:00).
  ThematicText resolveMorningSummary(int pendingCount) {
    return _fromCache(
      ThematicTextsCatalog.summaryCacheKey('morning'),
      ThematicTextsCatalog.morningSummary(pendingCount),
    );
  }

  /// Resumen de la tarde (19:00).
  ThematicText resolveEveningSummary(int pendingCount) {
    return _fromCache(
      ThematicTextsCatalog.summaryCacheKey('evening'),
      ThematicTextsCatalog.eveningSummary(pendingCount),
    );
  }

  /// Cierre de jornada.
  ThematicText resolveDayClosure(DayClosureStats stats) {
    return _fromCache(
      ThematicTextsCatalog.summaryCacheKey('closure'),
      ThematicTextsCatalog.dayClosure(stats),
    );
  }

  /// Alerta de racha en peligro (F2, decisión B).
  ThematicText resolveStreakAtRisk(int streakDays) {
    return _fromCache(
      ThematicTextsCatalog.summaryCacheKey('streak_at_risk'),
      ThematicTextsCatalog.streakAtRisk(streakDays),
    );
  }
}