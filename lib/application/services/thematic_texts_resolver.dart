import '../../data/hive/boxes/thematic_text_cache_box.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/user_settings.dart';
import 'reminder_schedule_calculator.dart';
import 'thematic_texts_catalog.dart';

/// Resuelve el texto de una notificación respetando el tema "Slate System".
///
/// Orden de resolución:
/// - Tema OFF (`slateSystemTheme == false`): devuelve `null`, y el llamador
///   usa los textos canónicos actuales (comportamiento idéntico a hoy).
/// - Tema ON: primero busca la variante generada con IA en [ThematicTextCache]
///   (si existe); si no, usa el catálogo local [ThematicTextsCatalog].
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
/// - Gating del opt-in: la generación exige `slateSystemTheme == true` Y
///   `useAIThematicTexts == true` (ambos), comprobados en el punto de guardado
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

  bool _isThemed(UserSettings settings) => settings.slateSystemTheme;

  ThematicText? _fromCache(String key, ThematicText fallback) {
    final cached = _cache?.get(key);
    if (cached != null) {
      return ThematicText(title: cached.title, body: cached.body);
    }
    return fallback;
  }

  /// Recordatorio de tarea. `null` si el tema está OFF (texto canónico).
  ThematicText? resolveTaskReminder(Task task, UserSettings settings) {
    if (!_isThemed(settings)) return null;
    return _fromCache(
      ThematicTextsCatalog.taskCacheKey(task),
      ThematicTextsCatalog.taskReminder(task),
    );
  }

  /// Resumen de la mañana (10:00). `null` si el tema está OFF.
  ThematicText? resolveMorningSummary(int pendingCount, UserSettings settings) {
    if (!_isThemed(settings)) return null;
    return _fromCache(
      ThematicTextsCatalog.summaryCacheKey('morning'),
      ThematicTextsCatalog.morningSummary(pendingCount),
    );
  }

  /// Resumen de la tarde (19:00). `null` si el tema está OFF.
  ThematicText? resolveEveningSummary(int pendingCount, UserSettings settings) {
    if (!_isThemed(settings)) return null;
    return _fromCache(
      ThematicTextsCatalog.summaryCacheKey('evening'),
      ThematicTextsCatalog.eveningSummary(pendingCount),
    );
  }

  /// Cierre de jornada. `null` si el tema está OFF (texto canónico).
  ThematicText? resolveDayClosure(
    DayClosureStats stats,
    UserSettings settings,
  ) {
    if (!_isThemed(settings)) return null;
    return _fromCache(
      ThematicTextsCatalog.summaryCacheKey('closure'),
      ThematicTextsCatalog.dayClosure(stats),
    );
  }
}