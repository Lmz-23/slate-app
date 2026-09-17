import 'package:flutter/material.dart';

/// Valores crudos (hex) de la paleta cálida del handoff de diseño.
///
/// Este archivo es la ÚNICA fuente de literales `Color(0x...)` para el nuevo
/// sistema de theming. Ningún otro archivo del sistema de tokens (ni,
/// eventualmente, ningún widget) debe declarar un `Color(0x...)` propio:
/// deben consumir los tokens semánticos de [SlateColors] en su lugar.
///
/// Ver docs/architecture/rediseno-identidad-visual.md (Decisión A1) y
/// docs/design/sistema-visual-fase3.md (sección 0) para el origen de cada
/// valor, incluidos los dos derivados marcados con asterisco por Aesthetic
/// (`priorityMediumDark`, `dangerLight`, `dangerDark`).
class SlatePalette {
  const SlatePalette._();

  // ---------------------------------------------------------------------
  // Modo claro
  // ---------------------------------------------------------------------
  static const Color backgroundLight = Color(0xFFFCF1E4);
  static const Color surfaceLight = Color(0xFFFFFBF3);
  static const Color surfaceAltLight = Color(0xFFF3DEC4); // fondo de píldora
  static const Color outlineLight = Color(0xFFE3D5C4); // borde indicador vacío
  static const Color textPrimaryLight = Color(0xFF4A3325);
  static const Color textSecondaryLight = Color(0xFF8C6F58);
  static const Color textTertiaryLight = Color(0xFFC0A98F);
  static const Color accentLight = Color(0xFFE8734F);
  static const Color successLight = Color(0xFF7FAE7A);
  static const Color priorityHighLight = Color(0xFFC15A4E);
  static const Color priorityMediumLight = Color(0xFFE3A94A);
  static const Color todayAccentLight = Color(0xFFE8734F);
  static const Color secondaryAccentLight = Color(0xFF5C87C4);

  /// Derivado por Aesthetic (sistema-visual-fase3.md §0, marcado con *):
  /// no está explícito en el mockup; separado deliberadamente de
  /// [priorityHighLight] porque `danger` es destructivo, no informativo.
  static const Color dangerLight = Color(0xFFB23B2E);

  // ---------------------------------------------------------------------
  // Modo oscuro
  // ---------------------------------------------------------------------
  static const Color backgroundDark = Color(0xFF241812);
  static const Color surfaceDark = Color(0xFF34241B);
  static const Color surfaceAltDark = Color(0xFF402C21); // track de barra / píldora
  static const Color outlineDark = Color(0xFF8F7460);
  static const Color textPrimaryDark = Color(0xFFFBEEE0);
  static const Color textSecondaryDark = Color(0xFFC9A88D);
  static const Color textTertiaryDark = Color(0xFF8F7460);
  static const Color accentDark = Color(0xFFE8734F);
  static const Color successDark = Color(0xFF8FC088);
  static const Color priorityHighDark = Color(0xFFE07362);

  /// Derivado por Aesthetic: aclara `#E3A94A` -> `#EDB868` (~10-15%), misma
  /// relación claro->oscuro que `success`.
  static const Color priorityMediumDark = Color(0xFFEDB868);

  /// Acento del día actual en filas semanales, distinto de `accent` solo en
  /// oscuro (para no competir visualmente con el FAB/selector).
  static const Color todayAccentDark = Color(0xFFF0A868);

  /// Derivado por Aesthetic (marcado con *).
  static const Color dangerDark = Color(0xFFD9614F);

  // ---------------------------------------------------------------------
  // Comunes a ambos modos
  // ---------------------------------------------------------------------
  static const Color onAccent = Color(0xFFFFFFFF);
  static const Color onSuccessLight = Color(0xFFFFFFFF);

  /// En oscuro el check es oscuro sobre verde claro (no blanco), tal como
  /// está en el mockup.
  static const Color onSuccessDark = Color(0xFF241812);

  // ---------------------------------------------------------------------
  // Sombras (solo modo claro, ver sistema-visual-fase3.md §0)
  // ---------------------------------------------------------------------

  /// `rgba(74,51,37,.06)` — sombra de tarjetas grandes.
  static const Color shadowCardLight = Color(0x0F4A3325);

  /// `rgba(74,51,37,.05)` — sombra de tiles.
  static const Color shadowTileLight = Color(0x0D4A3325);

  /// `rgba(232,115,79,.4)` — sombra del FAB.
  static const Color shadowFabLight = Color(0x66E8734F);

  // ---------------------------------------------------------------------
  // Paleta curada de categorías (sistema-visual-fase3.md §5, semilla
  // #5C87C4). Reemplaza a `AppColors.categoryColors` (17 tonos saturados)
  // SOLO para el selector de categorías NUEVAS: las categorías existentes
  // conservan su `colorHex` propio (Decisión A5, sin migración de datos).
  // Un único set para ambos modos: los 9 tonos ya están pensados para
  // convivir con la paleta cálida en claro y oscuro.
  // ---------------------------------------------------------------------
  static const List<Color> categoryPalette = [
    Color(0xFF5C87C4), // Azul semilla
    Color(0xFF7A9FD1), // Azul claro
    Color(0xFF6FAE9E), // Verde azulado
    Color(0xFF7FAE7A), // Verde (= success)
    Color(0xFFE3A94A), // Ámbar (= priorityMedium)
    Color(0xFFC97B5A), // Terracota
    Color(0xFFB5769E), // Ciruela suave
    Color(0xFF8C7FBF), // Lavanda grisáceo
    Color(0xFFA98F6F), // Marrón arena
  ];
}
