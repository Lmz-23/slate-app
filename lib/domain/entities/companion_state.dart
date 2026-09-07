import 'package:equatable/equatable.dart';

/// Estado persistido del "Sistema" (F3): quest diaria + marcadores quincenales.
///
/// Solo se persisten aquí las piezas que deben sobrevivir a reinicios:
/// - [questClaimedOn]: día (clave `yyyy-M-d`) en el que se reclamó la quest.
///   La quest se reinicia cada día: reclamar hoy no impide reclamar mañana.
/// - [questVisibleOn] + [questVisibleDecision]: la visibilidad de la quest se
///   DECIDE una vez por día (en el primer cálculo del día) y persiste ese día
///   entero, aunque después se borren tareas (decisión C). La decisión es
///   binaria y se guarda junto a su fecha para no recalcularla al reiniciar.
///
/// El resumen quincenal NO necesita estado persistente: su programación se
/// deriva cada vez de la fecha actual ([FortnightCalculator.nextFireTime]).
class CompanionState extends Equatable {
  final String id;

  /// Clave de día (`yyyy-M-d`) en la que se reclamó la quest. `null` = la
  /// quest de hoy aún no se ha reclamado.
  final String? questClaimedOn;

  /// Clave de día (`yyyy-M-d`) de la última decisión de visibilidad.
  final String? questVisibleOn;

  /// Decisión de visibilidad tomada para [questVisibleOn]. La quest solo se
  /// muestra si `true`, y la decisión persiste durante TODO el día.
  final bool questVisibleDecision;

  final DateTime updatedAt;

  const CompanionState({
    this.id = 'main_companion',
    this.questClaimedOn,
    this.questVisibleOn,
    this.questVisibleDecision = false,
    required this.updatedAt,
  });

  CompanionState copyWith({
    String? id,
    String? questClaimedOn,
    String? questVisibleOn,
    bool? questVisibleDecision,
    DateTime? updatedAt,
  }) {
    return CompanionState(
      id: id ?? this.id,
      questClaimedOn: questClaimedOn ?? this.questClaimedOn,
      questVisibleOn: questVisibleOn ?? this.questVisibleOn,
      questVisibleDecision: questVisibleDecision ?? this.questVisibleDecision,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        questClaimedOn,
        questVisibleOn,
        questVisibleDecision,
        updatedAt,
      ];
}