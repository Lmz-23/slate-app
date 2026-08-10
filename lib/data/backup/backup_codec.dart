import 'dart:convert';

import '../../domain/entities/badge.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/streak.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/user_settings.dart';
import '../../domain/enums/app_theme_mode.dart';
import '../../domain/enums/badge_type.dart';
import '../../domain/enums/recurrence_type.dart';
import '../../domain/enums/task_priority.dart';

/// Error de validación de un archivo de backup.
///
/// El mensaje es apto para mostrarse directamente en la UI (Ajustes → Datos).
class BackupException implements Exception {
  const BackupException(this.message);

  final String message;

  @override
  String toString() => 'BackupException: $message';
}

/// Contenido de un backup ya validado y listo para escribirse en Hive.
///
/// [appMeta] y [thematicTextCache] son mapas genéricos (primitivas) que se
/// conservan tal cual estaban en sus cajas.
class DecodedBackup {
  const DecodedBackup({
    required this.schemaVersion,
    required this.exportedAt,
    required this.tasks,
    required this.categories,
    required this.streaks,
    required this.badges,
    required this.userSettings,
    required this.appMeta,
    required this.thematicTextCache,
  });

  final int schemaVersion;
  final DateTime exportedAt;

  final List<Task> tasks;
  final List<Category> categories;
  final List<Streak> streaks;
  final List<Badge> badges;
  final UserSettings userSettings;

  final Map<String, dynamic> appMeta;
  final Map<String, dynamic> thematicTextCache;
}

/// Codec del archivo portable de backup de Slate (JSON versionado).
///
/// Fase 0 (Backup/Exportación): serializa el estado completo del usuario a un
/// JSON legible y versionado, y permite restaurarlo validando primero la
/// estructura completa ANTES de permitir escribir nada (import seguro).
///
/// Es 100% Dart puro (sin plugins), lo que lo hace hermético y testeable sin
/// entorno de dispositivo.
///
/// Formato v1:
/// ```
/// {
///   "app": "slate",
///   "schemaVersion": 1,
///   "exportedAt": "2026-08-09T10:00:00.000",
///   "data": {
///     "tasks": [ ... ],
///     "categories": [ ... ],
///     "streaks": [ ... ],
///     "badges": [ ... ],
///     "userSettings": { ... },
///     "appMeta": { ... },
///     "thematicTextCache": { ... }
///   }
/// }
/// ```
class BackupCodec {
  BackupCodec._();

  /// Identificador de la aplicación en la raíz del archivo.
  static const String appId = 'slate';

  /// Versión del esquema. El import SOLO acepta esta versión (no se migra:
  /// el objetivo de la Fase 0 es preservar, no migrar).
  static const int schemaVersion = 1;

  // ─────────────────────────────────────────────────────────────────────────
  // Codificación (export)
  // ─────────────────────────────────────────────────────────────────────────

  /// Serializa el estado completo a un JSON legible (2 espacios) y versionado.
  static String encode({
    required List<Task> tasks,
    required List<Category> categories,
    required List<Streak> streaks,
    required List<Badge> badges,
    required UserSettings userSettings,
    required Map<String, dynamic> appMeta,
    required Map<String, dynamic> thematicTextCache,
    DateTime? exportedAt,
  }) {
    final json = <String, dynamic>{
      'app': appId,
      'schemaVersion': schemaVersion,
      'exportedAt': (exportedAt ?? DateTime.now()).toIso8601String(),
      'data': <String, dynamic>{
        'tasks': tasks.map(_taskToJson).toList(),
        'categories': categories.map(_categoryToJson).toList(),
        'streaks': streaks.map(_streakToJson).toList(),
        'badges': badges.map(_badgeToJson).toList(),
        'userSettings': _settingsToJson(userSettings),
        'appMeta': appMeta,
        'thematicTextCache': thematicTextCache,
      },
    };

    try {
      return const JsonEncoder.withIndent('  ').convert(json);
    } on JsonUnsupportedObjectError catch (_) {
      throw const BackupException(
        'La caché auxiliar contiene valores no serializables a JSON.',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Decodificación (import) — valida TODO antes de producir datos escribibles
  // ─────────────────────────────────────────────────────────────────────────

  /// Decodifica y valida el contenido de un archivo de backup.
  ///
  /// Lanza [BackupException] con un mensaje legible si el contenido no es un
  /// backup válido de Slate. NUNCA escribe nada: la validación es completa
  /// antes de devolver [DecodedBackup], de modo que el importador puede
  /// rechazar el archivo sin tocar los datos actuales.
  static DecodedBackup decode(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const BackupException('El archivo no es un JSON válido.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const BackupException(
        'La raíz del archivo debe ser un objeto JSON.',
      );
    }
    return decodeJson(decoded);
  }

  /// Decodifica un mapa JSON ya parseado (usado por [decode] y por tests).
  static DecodedBackup decodeJson(Map<String, dynamic> json) {
    if (json['app'] != appId) {
      throw const BackupException(
        'El archivo no es una copia de seguridad de Slate.',
      );
    }

    final version = json['schemaVersion'];
    if (version is! int || version != schemaVersion) {
      throw BackupException(
        'Versión de esquema no soportada: $version. '
        'Esta versión de Slate solo importa copias con schemaVersion '
        '$schemaVersion.',
      );
    }

    // La sección "data" es la parte esencial: se valida ANTES que el resto de
    // metadatos para dar un error claro cuando el archivo no es un backup
    // realmente (p. ej. un JSON cualquiera con schemaVersion correcto).
    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      throw const BackupException('Falta la sección "data" del backup.');
    }

    final rawExportedAt = json['exportedAt'];
    if (rawExportedAt is! String) {
      throw const BackupException(
        'Falta la fecha de exportación (exportedAt) o no es válida.',
      );
    }
    final exportedAt = DateTime.tryParse(rawExportedAt);
    if (exportedAt == null) {
      throw const BackupException(
        'La fecha de exportación (exportedAt) no es válida.',
      );
    }

    // Valida el TIPO de cada sección antes de convertir entidades: si alguna
    // sección tiene un tipo incorrecto el import se rechaza sin escribir nada.
    for (final key in const ['tasks', 'categories', 'streaks', 'badges']) {
      final value = data[key];
      if (value != null && value is! List) {
        throw BackupException('La sección "$key" debe ser una lista.');
      }
    }
    final settingsRaw = data['userSettings'];
    if (settingsRaw != null && settingsRaw is! Map<String, dynamic>) {
      throw const BackupException(
        'La sección "userSettings" debe ser un objeto.',
      );
    }
    final appMetaRaw = data['appMeta'];
    if (appMetaRaw != null && appMetaRaw is! Map<String, dynamic>) {
      throw const BackupException('La sección "appMeta" debe ser un objeto.');
    }
    final cacheRaw = data['thematicTextCache'];
    if (cacheRaw != null && cacheRaw is! Map<String, dynamic>) {
      throw const BackupException(
        'La sección "thematicTextCache" debe ser un objeto.',
      );
    }

    try {
      final tasks = ((data['tasks'] as List?) ?? const [])
          .map((e) => _taskFromJson(_asMap(e, 'tasks')))
          .toList();
      final categories = ((data['categories'] as List?) ?? const [])
          .map((e) => _categoryFromJson(_asMap(e, 'categories')))
          .toList();
      final streaks = ((data['streaks'] as List?) ?? const [])
          .map((e) => _streakFromJson(_asMap(e, 'streaks')))
          .toList();
      final badges = ((data['badges'] as List?) ?? const [])
          .map((e) => _badgeFromJson(_asMap(e, 'badges')))
          .toList();
      final userSettings = settingsRaw == null
          ? const UserSettings()
          : _settingsFromJson(settingsRaw);

      return DecodedBackup(
        schemaVersion: version,
        exportedAt: exportedAt,
        tasks: tasks,
        categories: categories,
        streaks: streaks,
        badges: badges,
        userSettings: userSettings,
        appMeta: appMetaRaw ?? <String, dynamic>{},
        thematicTextCache: cacheRaw ?? <String, dynamic>{},
      );
    } on BackupException {
      rethrow;
    } catch (e) {
      throw BackupException(
        'El backup contiene entradas inválidas: $e',
      );
    }
  }

  static Map<String, dynamic> _asMap(Object? value, String section) {
    if (value is! Map<String, dynamic>) {
      throw BackupException(
        'La sección "$section" contiene una entrada que no es un objeto.',
      );
    }
    return value;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Dates
  // ─────────────────────────────────────────────────────────────────────────

  static String? _encDate(DateTime? value) => value?.toIso8601String();

  static DateTime? _optDate(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value);
  }

  static DateTime _reqDate(Object? value, String field) {
    final parsed = _optDate(value);
    if (parsed == null) {
      throw FormatException('Campo obligatorio "$field" no es una fecha.');
    }
    return parsed;
  }

  static String _reqString(Object? value, String field) {
    if (value is! String || value.isEmpty) {
      throw FormatException('Campo obligatorio "$field" no es texto.');
    }
    return value;
  }

  static T _enumByNameOr<T extends Enum>(List<T> values, Object? name, T fallback) {
    if (name is! String) return fallback;
    for (final v in values) {
      if (v.name == name) return v;
    }
    return fallback;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Task
  // ─────────────────────────────────────────────────────────────────────────

  static Map<String, dynamic> _taskToJson(Task t) {
    return <String, dynamic>{
      'id': t.id,
      'title': t.title,
      'notes': t.notes,
      'scheduledTime': _encDate(t.scheduledTime),
      'scheduledDate': _encDate(t.scheduledDate),
      'isCompleted': t.isCompleted,
      'priority': t.priority.name,
      'recurrence': t.recurrence.name,
      'recurrenceDays': t.recurrenceDays,
      'categoryId': t.categoryId,
      'createdAt': _encDate(t.createdAt),
      'completedAt': _encDate(t.completedAt),
      'parentTaskId': t.parentTaskId,
    };
  }

  static Task _taskFromJson(Map<String, dynamic> m) {
    return Task(
      id: _reqString(m['id'], 'id'),
      title: _reqString(m['title'], 'title'),
      notes: m['notes'] as String?,
      scheduledTime: _optDate(m['scheduledTime']),
      scheduledDate: _reqDate(m['scheduledDate'], 'scheduledDate'),
      isCompleted: m['isCompleted'] as bool? ?? false,
      priority: _enumByNameOr(TaskPriority.values, m['priority'], TaskPriority.normal),
      recurrence: _enumByNameOr(
          RecurrenceType.values, m['recurrence'], RecurrenceType.none),
      recurrenceDays: (m['recurrenceDays'] as List?)?.cast<int>(),
      categoryId: m['categoryId'] as String?,
      createdAt: _reqDate(m['createdAt'], 'createdAt'),
      completedAt: _optDate(m['completedAt']),
      parentTaskId: m['parentTaskId'] as String?,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Category
  // ─────────────────────────────────────────────────────────────────────────

  static Map<String, dynamic> _categoryToJson(Category c) {
    return <String, dynamic>{
      'id': c.id,
      'name': c.name,
      'colorHex': c.colorHex,
      'createdAt': _encDate(c.createdAt),
    };
  }

  static Category _categoryFromJson(Map<String, dynamic> m) {
    return Category(
      id: _reqString(m['id'], 'id'),
      name: _reqString(m['name'], 'name'),
      colorHex: _reqString(m['colorHex'], 'colorHex'),
      createdAt: _reqDate(m['createdAt'], 'createdAt'),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Streak
  // ─────────────────────────────────────────────────────────────────────────

  static Map<String, dynamic> _streakToJson(Streak s) {
    return <String, dynamic>{
      'id': s.id,
      'currentStreak': s.currentStreak,
      'longestStreak': s.longestStreak,
      'lastCompletedDate': _encDate(s.lastCompletedDate),
      'updatedAt': _encDate(s.updatedAt),
    };
  }

  static Streak _streakFromJson(Map<String, dynamic> m) {
    return Streak(
      id: _reqString(m['id'], 'id'),
      currentStreak: m['currentStreak'] as int? ?? 0,
      longestStreak: m['longestStreak'] as int? ?? 0,
      lastCompletedDate: _optDate(m['lastCompletedDate']),
      updatedAt: _reqDate(m['updatedAt'], 'updatedAt'),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Badge
  // ─────────────────────────────────────────────────────────────────────────
  //
  // OJO: `BadgeType` define un getter `name` (texto de la insignia, p. ej.
  // "Semana Perfecta") que SOMBREA el `.name` nativo del enum ("streak7").
  // Por eso el JSON usa un mapeo explícito por nombre de constante, que es
  // estable e independiente del orden del enum.
  static const Map<BadgeType, String> _badgeTypeNames = {
    BadgeType.streak3: 'streak3',
    BadgeType.streak7: 'streak7',
    BadgeType.streak14: 'streak14',
    BadgeType.streak21: 'streak21',
    BadgeType.streak30: 'streak30',
    BadgeType.streak60: 'streak60',
    BadgeType.streak90: 'streak90',
    BadgeType.streak180: 'streak180',
    BadgeType.streak365: 'streak365',
  };

  static final Map<String, BadgeType> _badgeTypesByName = {
    for (final entry in _badgeTypeNames.entries) entry.value: entry.key,
  };

  static Map<String, dynamic> _badgeToJson(Badge b) {
    return <String, dynamic>{
      'id': b.id,
      'type': _badgeTypeNames[b.type] ?? b.type.index.toString(),
      'name': b.name,
      'iconName': b.iconName,
      'unlockedAt': _encDate(b.unlockedAt),
      'isDisplayed': b.isDisplayed,
    };
  }

  static Badge _badgeFromJson(Map<String, dynamic> m) {
    return Badge(
      id: _reqString(m['id'], 'id'),
      type: _badgeTypesByName[m['type']] ?? BadgeType.streak3,
      name: _reqString(m['name'], 'name'),
      iconName: _reqString(m['iconName'], 'iconName'),
      unlockedAt: _reqDate(m['unlockedAt'], 'unlockedAt'),
      isDisplayed: m['isDisplayed'] as bool? ?? false,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UserSettings
  // ─────────────────────────────────────────────────────────────────────────

  static Map<String, dynamic> _settingsToJson(UserSettings s) {
    return <String, dynamic>{
      'id': s.id,
      'userName': s.userName,
      'dayResetHour': s.dayResetHour,
      'notificationsEnabled': s.notificationsEnabled,
      'themeMode': s.themeMode.name,
      'unlockedThemeIds': s.unlockedThemeIds,
      'timezone': s.timezone,
      'autoDetectTimezone': s.autoDetectTimezone,
      'locationPermissionGranted': s.locationPermissionGranted,
      'useAINotifications': s.useAINotifications,
      'notificationSound': s.notificationSound,
      'notificationVibration': s.notificationVibration,
      'notificationBadge': s.notificationBadge,
      'notificationImagePaths': s.notificationImagePaths,
      'notificationTextContext': s.notificationTextContext,
      'notificationLeadTimeMinutes': s.notificationLeadTimeMinutes,
      'dailyReminderEnabled': s.dailyReminderEnabled,
      'dailyReminderHour1': s.dailyReminderHour1,
      'dailyReminderHour2': s.dailyReminderHour2,
      'useAIThematicTexts': s.useAIThematicTexts,
      'enableDayClosure': s.enableDayClosure,
    };
  }

  static UserSettings _settingsFromJson(Map<String, dynamic> m) {
    return UserSettings(
      id: m['id'] as String? ?? 'singleton',
      userName: m['userName'] as String? ?? 'Usuario',
      dayResetHour: m['dayResetHour'] as int? ?? 4,
      notificationsEnabled: m['notificationsEnabled'] as bool? ?? true,
      themeMode: _enumByNameOr(
          AppThemeMode.values, m['themeMode'], AppThemeMode.dark),
      unlockedThemeIds:
          (m['unlockedThemeIds'] as List?)?.cast<String>() ?? const [],
      timezone: m['timezone'] as String? ?? 'America/Bogota',
      autoDetectTimezone: m['autoDetectTimezone'] as bool? ?? false,
      locationPermissionGranted: m['locationPermissionGranted'] as bool? ?? false,
      useAINotifications: m['useAINotifications'] as bool? ?? false,
      notificationSound: m['notificationSound'] as bool? ?? true,
      notificationVibration: m['notificationVibration'] as bool? ?? true,
      notificationBadge: m['notificationBadge'] as bool? ?? true,
      notificationImagePaths:
          (m['notificationImagePaths'] as List?)?.cast<String>() ?? const [],
      notificationTextContext: m['notificationTextContext'] as String?,
      notificationLeadTimeMinutes: m['notificationLeadTimeMinutes'] as int? ?? 0,
      dailyReminderEnabled: m['dailyReminderEnabled'] as bool? ?? true,
      dailyReminderHour1: m['dailyReminderHour1'] as int? ?? 10,
      dailyReminderHour2: m['dailyReminderHour2'] as int? ?? 19,
      useAIThematicTexts: m['useAIThematicTexts'] as bool? ?? false,
      enableDayClosure: m['enableDayClosure'] as bool? ?? false,
    );
  }
}