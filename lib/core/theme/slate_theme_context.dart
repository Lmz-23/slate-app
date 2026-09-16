import 'package:flutter/material.dart';

import 'slate_colors.dart';
import 'slate_shapes.dart';
import 'slate_typography.dart';

/// Azúcar sintáctico para acceder a los tokens del nuevo sistema visual
/// desde cualquier [BuildContext]. Ver Decisión A1 de
/// docs/architecture/rediseno-identidad-visual.md.
///
/// Ejemplo: `context.slate.textPrimary`, `context.slateText.sectionTitle`.
extension SlateThemeContext on BuildContext {
  /// Tokens semánticos de color, con fallback obligatorio a
  /// [SlateColors.dark] (ver [SlateColors.of]).
  SlateColors get slate => SlateColors.of(this);

  /// Tokens tipográficos, con fallback obligatorio a
  /// [SlateTypography.standard] (ver [SlateTypography.of]).
  SlateTypography get slateText => SlateTypography.of(this);

  /// Radios y sombras, con fallback obligatorio a [SlateShapes.dark] (ver
  /// [SlateShapes.of]).
  SlateShapes get slateShapes => SlateShapes.of(this);
}
