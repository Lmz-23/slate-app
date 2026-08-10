import 'package:hive/hive.dart';

import '../backup/backup_codec.dart';
import '../backup/backup_file_store.dart';
import '../hive/boxes/badges_box.dart';
import '../hive/boxes/categories_box.dart';
import '../hive/boxes/companion_state_box.dart';
import '../hive/boxes/player_progress_box.dart';
import '../hive/boxes/settings_box.dart';
import '../hive/boxes/streaks_box.dart';
import '../hive/boxes/tasks_box.dart';
import '../hive/boxes/thematic_text_cache_box.dart';

/// Resumen del resultado de una operación de exportación/importación.
class BackupResult {
  const BackupResult({
    required this.taskCount,
    required this.categoryCount,
    required this.streakCount,
    required this.badgeCount,
    required this.exportedAt,
    this.filePath,
  });

  final int taskCount;
  final int categoryCount;
  final int streakCount;
  final int badgeCount;
  final DateTime exportedAt;

  /// Ruta del archivo (solo exportación).
  final String? filePath;

  bool get isExport => filePath != null;
}

/// Servicio de backup (Fase 0): exporta/importa el estado completo del usuario
/// entre Hive y un archivo JSON portable.
///
/// Reglas de persistencia/coherencia:
/// - Al EXPORTAR se leen SIEMPRE las cajas actuales (fuente de verdad).
/// - Al IMPORTAR se valida TODO primero (BackupCodec.decode) y solo después se
///   sobrescriben las cajas objetivo. La propagación a los providers vivos la
///   hace el BackupController (refresca los notifiers tras importar).
class BackupService {
  BackupService({
    required TasksBox tasksBox,
    required CategoriesBox categoriesBox,
    required StreaksBox streaksBox,
    required BadgesBox badgesBox,
    required SettingsBox settingsBox,
    ThematicTextCache? thematicCache,
    Box<dynamic>? appMetaBox,
    // F4: cajas del Jugador/Sistema. OPCIONALES para no romper constructores
    // existentes: si no se inyectan, el backup simplemente no incluye esas
    // secciones (equivalente al comportamiento pre-F4).
    PlayerProgressBox? playerProgressBox,
    CompanionStateBox? companionStateBox,
    BackupFileStore? fileStore,
  })  : _tasksBox = tasksBox,
        _categoriesBox = categoriesBox,
        _streaksBox = streaksBox,
        _badgesBox = badgesBox,
        _settingsBox = settingsBox,
        _thematicCache = thematicCache,
        _appMetaBoxOverride = appMetaBox,
        _playerBox = playerProgressBox,
        _companionBox = companionStateBox,
        _fileStore = fileStore ?? BackupFileStore();

  final TasksBox _tasksBox;
  final CategoriesBox _categoriesBox;
  final StreaksBox _streaksBox;
  final BadgesBox _badgesBox;
  final SettingsBox _settingsBox;
  final ThematicTextCache? _thematicCache;
  final Box<dynamic>? _appMetaBoxOverride;
  final PlayerProgressBox? _playerBox;
  final CompanionStateBox? _companionBox;
  final BackupFileStore _fileStore;

  Future<Box<dynamic>> _appMetaBox() async {
    // En producción la caja 'app_meta' ya está abierta en main(); openBox es
    // idempotente y devuelve la misma instancia. En tests se inyecta.
    return _appMetaBoxOverride ?? await Hive.openBox<dynamic>('app_meta');
  }

  /// Exporta el estado actual a un archivo JSON y devuelve el resumen con la
  /// ruta del archivo generado.
  Future<BackupResult> exportData({DateTime? now}) async {
    final metaBox = await _appMetaBox();

    final tasks = _tasksBox.getAll();
    final categories = _categoriesBox.getAll();
    final streaks = _streaksBox.box.values.toList();
    final badges = _badgesBox.getAll();
    final settings = _settingsBox.getSettings();
    final appMeta = Map<String, dynamic>.from(metaBox.toMap());
    final cache = _thematicCache?.getAll() ?? <String, dynamic>{};

    final exportedAt = now ?? DateTime.now();
    final json = BackupCodec.encode(
      tasks: tasks,
      categories: categories,
      streaks: streaks,
      badges: badges,
      userSettings: settings,
      appMeta: appMeta,
      thematicTextCache: cache,
      // F4: se leen SIEMPRE las cajas actuales (fuente de verdad). Si no se
      // inyectaron (constructor sin boxes), la sección se omite del JSON.
      playerProgress: _playerBox?.getProfile(),
      companionState: _companionBox?.getState(),
      exportedAt: exportedAt,
    );

    final path = await _fileStore.writeExport(json, timestamp: exportedAt);

    return BackupResult(
      taskCount: tasks.length,
      categoryCount: categories.length,
      streakCount: streaks.length,
      badgeCount: badges.length,
      exportedAt: exportedAt,
      filePath: path,
    );
  }

  /// Importa un backup desde la ruta de un archivo: valida TODO el contenido y
  /// luego SOBRESCRIBE las cajas objetivo (regla decidida: import = overwrite,
  /// con confirmación explícita en la UI antes de llamar aquí).
  ///
  /// Lanza [BackupException] si el archivo es inválido; en ese caso NO toca
  /// ningún dato actual (la validación es previa a cualquier escritura).
  Future<BackupResult> importFromPath(String path) async {
    final content = await _fileStore.readFile(path);
    final decoded = BackupCodec.decode(content);
    await _overwriteAll(decoded);
    return BackupResult(
      taskCount: decoded.tasks.length,
      categoryCount: decoded.categories.length,
      streakCount: decoded.streaks.length,
      badgeCount: decoded.badges.length,
      exportedAt: decoded.exportedAt,
    );
  }

  Future<void> _overwriteAll(DecodedBackup decoded) async {
    final metaBox = await _appMetaBox();

    // Tareas.
    await _tasksBox.box.clear();
    for (final task in decoded.tasks) {
      await _tasksBox.box.put(task.id, task);
    }

    // Categorías.
    await _categoriesBox.box.clear();
    for (final category in decoded.categories) {
      await _categoriesBox.box.put(category.id, category);
    }

    // Rachas (singleton 'main_streak' incluido).
    await _streaksBox.box.clear();
    for (final streak in decoded.streaks) {
      await _streaksBox.box.put(streak.id, streak);
    }

    // Insignias.
    await _badgesBox.box.clear();
    for (final badge in decoded.badges) {
      await _badgesBox.box.put(badge.id, badge);
    }

    // Ajustes del usuario.
    await _settingsBox.box.clear();
    await _settingsBox.box.put(
      SettingsBox.singletonBoxKey,
      decoded.userSettings,
    );

    // Flags auxiliares (app_meta): sobrescribir completamente.
    await metaBox.clear();
    for (final entry in decoded.appMeta.entries) {
      await metaBox.put(entry.key, entry.value);
    }

    // Caché temática IA.
    await _thematicCache?.clear();
    for (final entry in decoded.thematicTextCache.entries) {
      final raw = entry.value;
      if (raw is Map<String, dynamic>) {
        await _thematicCache?.putRaw(entry.key, raw);
      }
    }

    // F4: perfil de Jugador y estado del Sistema. Solo se sobrescriben cuando
    // el backup LOS INCLUYE: un backup anterior a F4 (secciones `null`) NO
    // toca estas cajas, conservando el progreso actual (XP/nivel) y el estado
    // de quest/quincena del usuario.
    if (decoded.playerProgress != null) {
      await _playerBox?.updateProfile(decoded.playerProgress!);
    }
    if (decoded.companionState != null) {
      await _companionBox?.updateState(decoded.companionState!);
    }
  }
}