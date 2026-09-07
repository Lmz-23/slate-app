/// Rango de Jugador (E→S) mostrado en la tarjeta "Jugador" de Estadísticas.
///
/// Escalera de producto (decisión A): 1-9 E, 10-19 D, 20-29 C, 30-49 B,
/// 50-69 A, 70+ S. Es un rango derivado del NIVEL (no del XP directo).
enum PlayerRank {
  e('E'),
  d('D'),
  c('C'),
  b('B'),
  a('A'),
  s('S');

  const PlayerRank(this.displayName);

  final String displayName;
}