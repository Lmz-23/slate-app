import '../../data/hive/boxes/thematic_text_cache_box.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/user_settings.dart';
import 'reminder_schedule_calculator.dart';
import 'thematic_texts_catalog.dart';
import 'thematic_texts_generator.dart';

/// Resuelve el texto de una notificación respetando el tema "Slate System".
///
/// Orden de resolución:
/// - Tema OFF (`slateSystemTheme == false`): devuelve `null`, y el llamador
///   usa los textos canónicos actuales (comportamiento idéntico a hoy).
/// - Tema ON: primero busca la variante generada con IA en [ThematicTextCache]
///   (si existe); si no, usa el catálogo local [ThematicTextsCatalog].
///
/// Nunca lanza ni bloquea: la caché se lee de forma síncrona y siempre existe
/// un fallback local. Si hay un [generator] disponible y la clave no está en
/// caché, se dispara en segundo plano la generación con IA para próximas
/// programaciones (nunca en el path de disparo de la notificación).
class ThematicTextsResolver {
  const ThematicTextsResolver({ThematicTextCache? cache, ThematicTextsGenerator? generator})
      : _cache = cache,
        _generator = generator;

  final ThematicTextCache? _cache;
  final ThematicTextsGenerator? _generator;

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
    _generator?.ensureTaskVariant(task);
    return _fromCache(
      ThematicTextsCatalog.taskCacheKey(task),
      ThematicTextsCatalog.taskReminder(task),
    );
  }

  /// Resumen de la mañana (10:00). `null` si el tema está OFF.
  ThematicText? resolveMorningSummary(int pendingCount, UserSettings settings) {
    if (!_isThemed(settings)) return null;
    _generator?.ensureSummaryVariants();
    return _fromCache(
      ThematicTextsCatalog.summaryCacheKey('morning'),
      ThematicTextsCatalog.morningSummary(pendingCount),
    );
  }

  /// Resumen de la tarde (19:00). `null` si el tema está OFF.
  ThematicText? resolveEveningSummary(int pendingCount, UserSettings settings) {
    if (!_isThemed(settings)) return null;
    _generator?.ensureSummaryVariants();
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
    _generator?.ensureSummaryVariants();
    return _fromCache(
      ThematicTextsCatalog.summaryCacheKey('closure'),
      ThematicTextsCatalog.dayClosure(stats),
    );
  }
}