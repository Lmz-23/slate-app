import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/slate_theme_context.dart';

/// Tamaños de [StreakMark] definidos por sistema-visual-fase3.md §9: solo dos
/// variantes, sin escala arbitraria.
enum StreakMarkSize {
  /// 9px — junto a "N días seguidos" en `DailyProgressCard`.
  small,

  /// 18-20px — bloque "Racha" de Progreso y base del ícono de navegación.
  large,
}

/// Marca de racha: rombo con una esquina recta (`borderRadius 50% 50% 50% 0`
/// + `rotate(45deg)`), reemplaza a `StreakBadge` en las superficies
/// rediseñadas (Decisión A3). Siempre color `accent`, en ambos modos y
/// contextos: no hay "niveles de rombo" por antigüedad de racha.
class StreakMark extends StatelessWidget {
  final StreakMarkSize size;

  /// Color opcional (por defecto `context.slate.accent`, ver §9: "siempre
  /// accent"). Único override permitido: el glifo del snackbar de subida de
  /// nivel, que necesita `onAccent` al pintarse sobre un fondo `accent`
  /// pleno (sistema-visual-fase3.md §6) — no es un "nivel de rombo" por
  /// racha, sigue sin variar con el tema ni el valor de la racha.
  final Color? color;

  const StreakMark({super.key, this.size = StreakMarkSize.small, this.color});

  double get _dimension => size == StreakMarkSize.small ? 9.0 : 20.0;

  @override
  Widget build(BuildContext context) {
    final dimension = _dimension;
    return Transform.rotate(
      angle: math.pi / 4,
      child: Container(
        width: dimension,
        height: dimension,
        decoration: BoxDecoration(
          color: color ?? context.slate.accent,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(dimension / 2),
            topRight: Radius.circular(dimension / 2),
            bottomLeft: Radius.circular(dimension / 2),
            bottomRight: Radius.zero,
          ),
        ),
      ),
    );
  }
}
