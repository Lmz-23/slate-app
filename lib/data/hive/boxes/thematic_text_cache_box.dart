import 'package:hive/hive.dart';

/// Entrada de la caché local de variantes temáticas generadas con IA.
class ThematicTextCacheEntry {
  final String title;
  final String body;
  final DateTime createdAt;

  const ThematicTextCacheEntry({
    required this.title,
    required this.body,
    required this.createdAt,
  });
}

/// Caché Hive de los textos temáticos generados con IA.
///
/// Se guarda en el dispositivo (local-first) y se consulta SOLO en el momento
/// de programar la notificación (nunca en el disparo: la app puede estar
/// cerrada). Si no hay red o API key, la notificación usa el catálogo local.
///
/// Los valores se almacenan como mapas de primitivas (Hive los soporta de
/// forma nativa), por lo que no requiere registrar un adapter adicional.
class ThematicTextCache {
  static const String _boxName = 'thematic_texts_cache';

  late Box<dynamic> _box;

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  bool get isOpen => Hive.isBoxOpen(_boxName);

  ThematicTextCacheEntry? get(String key) {
    if (!isOpen) return null;
    final raw = _box.get(key);
    if (raw is! Map) return null;
    final title = raw['title'];
    final body = raw['body'];
    if (title is! String || body is! String || title.isEmpty || body.isEmpty) {
      return null;
    }
    final createdAtRaw = raw['createdAt'];
    return ThematicTextCacheEntry(
      title: title,
      body: body,
      createdAt: createdAtRaw is String
          ? (DateTime.tryParse(createdAtRaw) ?? DateTime.fromMillisecondsSinceEpoch(0))
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Future<void> put(String key, ThematicTextCacheEntry entry) async {
    if (!isOpen) return;
    await _box.put(key, {
      'title': entry.title,
      'body': entry.body,
      'createdAt': entry.createdAt.toIso8601String(),
    });
  }

  Future<void> clear() async {
    if (!isOpen) return;
    await _box.clear();
  }

  /// Devuelve TODAS las entradas en bruto (mapas de primitivas), tal y como se
  /// almacenan. Se usa por el backup/exportación (Fase 0): la caché temática
  /// forma parte del estado portable del usuario.
  Map<String, dynamic> getAll() {
    if (!isOpen) return <String, dynamic>{};
    return Map<String, dynamic>.from(_box.toMap());
  }

  /// Escribe una entrada en bruto directamente (usado al restaurar un backup).
  Future<void> putRaw(String key, Map<String, dynamic> raw) async {
    if (!isOpen) return;
    await _box.put(key, raw);
  }
}