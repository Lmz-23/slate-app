import 'package:flutter/material.dart';

import 'tokens/slate_palette.dart';

/// Radios y sombras del nuevo sistema visual (Decisión A1).
///
/// Las sombras son nullable por modo a propósito: en oscuro la separación
/// de superficie se hace solo por color (`surface` sobre `background`, sin
/// sombra), tal como fija sistema-visual-fase3.md §0.
@immutable
class SlateShapes extends ThemeExtension<SlateShapes> {
  const SlateShapes({
    required this.cardShadow,
    required this.tileShadow,
    required this.fabShadow,
  });

  /// Radio de tarjetas contenedoras grandes (daily progress, player card).
  static const double radiusLarge = 20;

  /// Radio de tiles de lista (task tile, filas de settings).
  static const double radiusMedium = 18;

  /// Radio de elementos pequeños (celda de fecha, chips, botones de diálogo).
  static const double radiusSmall = 14;

  /// Radio de píldoras/contadores.
  static const double radiusPill = 10;

  /// Sombra de tarjetas grandes. `null` en oscuro.
  final List<BoxShadow>? cardShadow;

  /// Sombra de tiles. `null` en oscuro.
  final List<BoxShadow>? tileShadow;

  /// Sombra del FAB. `null` en oscuro.
  final List<BoxShadow>? fabShadow;

  static const SlateShapes light = SlateShapes(
    cardShadow: [
      BoxShadow(
        color: SlatePalette.shadowCardLight,
        offset: Offset(0, 4),
        blurRadius: 14,
      ),
    ],
    tileShadow: [
      BoxShadow(
        color: SlatePalette.shadowTileLight,
        offset: Offset(0, 3),
        blurRadius: 10,
      ),
    ],
    fabShadow: [
      BoxShadow(
        color: SlatePalette.shadowFabLight,
        offset: Offset(0, 6),
        blurRadius: 16,
      ),
    ],
  );

  static const SlateShapes dark = SlateShapes(
    cardShadow: null,
    tileShadow: null,
    fabShadow: null,
  );

  /// Resuelve [SlateShapes] desde el [BuildContext] con fallback obligatorio,
  /// mismo criterio que [SlateColors.of].
  static SlateShapes of(BuildContext context) {
    return Theme.of(context).extension<SlateShapes>() ?? SlateShapes.dark;
  }

  @override
  SlateShapes copyWith({
    List<BoxShadow>? cardShadow,
    List<BoxShadow>? tileShadow,
    List<BoxShadow>? fabShadow,
  }) {
    return SlateShapes(
      cardShadow: cardShadow ?? this.cardShadow,
      tileShadow: tileShadow ?? this.tileShadow,
      fabShadow: fabShadow ?? this.fabShadow,
    );
  }

  @override
  SlateShapes lerp(ThemeExtension<SlateShapes>? other, double t) {
    if (other is! SlateShapes) return this;
    // Las sombras no se interpolan de forma significativa entre nullable y
    // no-nullable (oscuro no tiene sombra); se resuelve por umbral en t.
    return t < 0.5 ? this : other;
  }
}
