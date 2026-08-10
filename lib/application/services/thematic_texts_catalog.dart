import '../../domain/entities/task.dart';
import '../../domain/enums/badge_type.dart';
import 'reminder_schedule_calculator.dart';

/// Texto temático (título + cuerpo) de una notificación.
class ThematicText {
  final String title;
  final String body;

  const ThematicText({required this.title, required this.body});
}

/// Catálogo LOCAL de textos temáticos "Slate System" (siempre disponible).
///
/// Inspiración estética/nominal del estilo de ventanas del "System" de la obra
/// "Solo Leveling" (NOTA LEGAL: textos adaptados propios, sin copiar frases
/// literales largas de la obra ni arte). Cada tipo de notificación tiene una
/// variante temática en español con glifos ▶ ◇ ⚠ ◆ y un tono motivacional de
/// progresión por rangos/niveles.
///
/// Este catálogo es el FALLBACK final: se usa cuando el tema Slate System está
/// activado y no existe una variante generada con IA en caché. Cuando el tema
/// está OFF, las notificaciones usan exactamente los textos canónicos actuales
/// (ver [ReminderScheduleCalculator]).
///
/// También centraliza la subnomenclatura de rangos/niveles de las 9 insignias
/// de racha (escalera de hitos) usada por la vitrina y por el cierre de jornada.
class ThematicTextsCatalog {
  const ThematicTextsCatalog._();

  // ── Glifos del estilo "System" ────────────────────────────────────────────
  static const String _quest = '▶'; // misión/daily quest (normal)
  static const String _info = '◇'; // reporte/informativo (normal)
  static const String _warn = '⚠'; // advertencia (urgencia)
  static const String _rank = '◆'; // éxito/cierre (niveles)

  // ── Claves de caché de textos con IA ──────────────────────────────────────
  static String _normalize(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Clave de caché de la variante IA del recordatorio de [task].
  ///
  /// Incluye el id de la tarea Y el título normalizado: si el usuario edita el
  /// título, la clave cambia y se regenera la variante; si solo cambia la hora,
  /// la clave permanece (la variante IA es temática, no horaria).
  static String taskCacheKey(Task task) =>
      'task|${task.id}|${_normalize(task.title)}';

  /// Clave de caché de la variante IA de un resumen/cierre global:
  /// [kind] = 'morning' | 'evening' | 'closure'.
  static String summaryCacheKey(String kind) => 'summary|$kind';

  // ── Recordatorio de tarea (quest) ─────────────────────────────────────────
  static ThematicText taskReminder(Task task) {
    final time = ReminderScheduleCalculator.effectiveDateTime(task);
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return ThematicText(
      title: '$_quest Daily Quest',
      body: '$_quest La misión "${task.title}" te espera a las $hh:$mm. '
          'Complétala para fortalecer tu rango.',
    );
  }

  // ── Resumen de la mañana (System Report) ──────────────────────────────────
  static ThematicText morningSummary(int pendingCount) {
    final misiones = pendingCount == 1 ? '1 misión' : '$pendingCount misiones';
    return ThematicText(
      title: '$_info System Report',
      body: '$_info Quedan $misiones pendientes para la jornada de hoy. '
          'Cada misión completada eleva tu progreso.',
    );
  }

  // ── Resumen de la tarde (Advertencia del Sistema) ─────────────────────────
  static ThematicText eveningSummary(int pendingCount) {
    final misiones = pendingCount == 1 ? '1 misión' : '$pendingCount misiones';
    return ThematicText(
      title: '$_warn Advertencia del Sistema',
      body: '$_warn Aún no has completado ninguna misión. Te esperan '
          '$misiones. Tu progreso de hoy peligra si no actúas.',
    );
  }

  // ── Cierre de jornada (System Report — Jornada completada) ────────────────
  static ThematicText dayClosure(DayClosureStats stats) {
    final pending = stats.total - stats.completed;
    final hito = stats.milestone != null ? slateBadgeTitle(stats.milestone!) : null;
    var body = '$_rank Jornada cerrada: ${stats.completed}/${stats.total} '
        'misiones completadas, $pending pendientes.';
    if (stats.currentStreak > 0) {
      body += ' Racha vigente: ${stats.currentStreak} día${stats.currentStreak == 1 ? '' : 's'}.';
    }
    if (hito != null) {
      body += ' Hito alcanzado: $hito.';
    }
    return ThematicText(
      title: '$_rank System Report — Jornada completada',
      body: body,
    );
  }

  // ── Alerta de racha en peligro (F2, decisión B) ────────────────────────────
  static ThematicText streakAtRisk(int streakDays) {
    final dias = streakDays == 1 ? '1 día' : '$streakDays días';
    return ThematicText(
      title: '$_warn Racha en peligro',
      body: '$_warn Tu racha de $dias se perderá si no completas una misión hoy.',
    );
  }

  // ── Transición "Nivel subió" (SnackBar in-app de la tarjeta Jugador) ──────
  static String levelUpMessage(int level) {
    return '$_rank Nivel subió — Ahora eres Nivel $level';
  }

  // ── Subnomenclatura de niveles/rangos de insignias (SL) ───────────────────
  /// Título SL del hito [type] (p. ej. "Rango E · Nivel I").
  static String slateBadgeTitle(BadgeType type) => _slateBadges[type]!.title;

  /// Apodo SL del hito (p. ej. "Cazador Novato").
  static String slateBadgeFlavor(BadgeType type) => _slateBadges[type]!.flavor;

  /// Icono sugerido para la vitrina cuando el tema SL está activo.
  static String slateBadgeIconName(BadgeType type) => _slateBadges[type]!.icon;

  static const Map<BadgeType, _SlateBadgeTheme> _slateBadges = {
    BadgeType.streak3: _SlateBadgeTheme(
      title: 'Rango E · Nivel I',
      flavor: 'Cazador Novato',
      icon: 'star',
    ),
    BadgeType.streak7: _SlateBadgeTheme(
      title: 'Rango E · Nivel II',
      flavor: 'Semana Perfecta',
      icon: 'moon',
    ),
    BadgeType.streak14: _SlateBadgeTheme(
      title: 'Rango D · Nivel I',
      flavor: 'Aprendiz',
      icon: 'sword',
    ),
    BadgeType.streak21: _SlateBadgeTheme(
      title: 'Rango D · Nivel II',
      flavor: 'Hábito Formado',
      icon: 'shield',
    ),
    BadgeType.streak30: _SlateBadgeTheme(
      title: 'Rango C · Nivel I',
      flavor: 'Asedio Prolongado',
      icon: 'award',
    ),
    BadgeType.streak60: _SlateBadgeTheme(
      title: 'Rango B · Nivel I',
      flavor: 'Doble Asedio',
      icon: 'medal',
    ),
    BadgeType.streak90: _SlateBadgeTheme(
      title: 'Rango A · Nivel I',
      flavor: 'Élite Nacional',
      icon: 'crown',
    ),
    BadgeType.streak180: _SlateBadgeTheme(
      title: 'Rango S · Nivel I',
      flavor: 'Sobresaliente S',
      icon: 'diamond',
    ),
    BadgeType.streak365: _SlateBadgeTheme(
      title: 'Nivel Nacional',
      flavor: 'Leyenda',
      icon: 'rocket',
    ),
  };
}

class _SlateBadgeTheme {
  final String title;
  final String flavor;
  final String icon;

  const _SlateBadgeTheme({
    required this.title,
    required this.flavor,
    required this.icon,
  });
}