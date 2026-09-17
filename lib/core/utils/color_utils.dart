import 'package:flutter/material.dart';

/// Utilidades de color independientes del sistema de theming.
///
/// `fromHex` se usa exclusivamente para datos de usuario (`Category.colorHex`
/// persistido en Hive), no para color de UI — por eso vive fuera de
/// `core/theme/` (Decisión A1 de docs/architecture/rediseno-identidad-visual.md:
/// "Sobrevive fromHex ... trasladado a core/utils/color_utils.dart").
class ColorUtils {
  const ColorUtils._();

  /// Convierte un hex (`#RRGGBB` o `RRGGBB`) en un [Color] opaco.
  static Color fromHex(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
