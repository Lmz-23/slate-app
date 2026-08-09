import '../../data/hive/boxes/thematic_text_cache_box.dart';
import '../../domain/entities/task.dart';
import 'ai_service.dart';
import 'thematic_texts_catalog.dart';

/// Genera variantes temáticas (Slate System) de las notificaciones con IA y
/// las guarda en la caché local.
///
/// Reglas:
/// - Se invoca al GUARDAR una tarea o al generar contenido (nunca en el
///   disparo de la notificación: la app puede estar cerrada).
/// - Si no hay API key, red o el servicio falla, NO hace nada y la
///   notificación usa el catálogo local (fallback final).
/// - Es idempotente por clave: si la variante ya está en caché (o hay una
///   generación en curso para esa clave) no vuelve a llamar a la IA.
class ThematicTextsGenerator {
  ThematicTextsGenerator({AIService? aiService, ThematicTextCache? cache})
      : _aiService = aiService ?? AIService(),
        _cache = cache;

  final AIService _aiService;
  final ThematicTextCache? _cache;

  /// Claves con una generación en curso (evita llamadas duplicadas en paralelo
  /// cuando varias notificaciones se resuelven a la vez).
  final Set<String> _inFlight = {};

  /// Genera (si falta) la variante temática del recordatorio de [task].
  Future<void> ensureTaskVariant(Task task) => _ensure(
        key: ThematicTextsCatalog.taskCacheKey(task),
        eventType: 'task',
        titleContext: task.title,
      );

  /// Genera (si faltan) las variantes de los textos globales: resumen de la
  /// mañana, resumen de la tarde y cierre de jornada.
  Future<void> ensureSummaryVariants() async {
    await Future.wait([
      _ensure(
        key: ThematicTextsCatalog.summaryCacheKey('morning'),
        eventType: 'morning',
        titleContext: 'resumen de la mañana',
      ),
      _ensure(
        key: ThematicTextsCatalog.summaryCacheKey('evening'),
        eventType: 'evening',
        titleContext: 'resumen de la tarde',
      ),
      _ensure(
        key: ThematicTextsCatalog.summaryCacheKey('closure'),
        eventType: 'closure',
        titleContext: 'cierre de jornada',
      ),
    ]);
  }

  Future<void> _ensure({
    required String key,
    required String eventType,
    required String titleContext,
  }) async {
    final cache = _cache;
    if (!_aiService.canUseAI || cache == null) return;
    if (cache.get(key) != null) return;
    if (!_inFlight.add(key)) return;
    try {
      final result = await _aiService.generateThematicText(
        eventType: eventType,
        titleContext: titleContext,
      );
      if (result != null) {
        await cache.put(
          key,
          ThematicTextCacheEntry(
            title: result.title,
            body: result.body,
            createdAt: DateTime.now(),
          ),
        );
      }
    } catch (_) {
      // Nunca bloquear ni propagar: el catálogo local cubre la notificación.
    } finally {
      _inFlight.remove(key);
    }
  }
}