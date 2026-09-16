import 'package:flutter/material.dart';

/// Tipografía del nuevo sistema visual: Nunito, empaquetada como asset local
/// (Decisión A2 de docs/architecture/rediseno-identidad-visual.md). No se usa
/// `google_fonts`: el proyecto es local-first y evita cualquier descarga de
/// red o modo de fallo de red para algo tan básico como el texto.
///
/// Pesos disponibles como asset (ver pubspec.yaml): 400 (Regular), 600
/// (SemiBold), 700 (Bold), 800 (ExtraBold).
@immutable
class SlateTypography extends ThemeExtension<SlateTypography> {
  const SlateTypography({
    required this.screenTitle,
    required this.sectionTitle,
    required this.bodyStrong,
    required this.body,
    required this.metadata,
    required this.tinyLabel,
  });

  static const String fontFamily = 'Nunito';

  /// 24px/800 — títulos de pantalla.
  final TextStyle screenTitle;

  /// 14px/700 — títulos de sección o tarjeta.
  final TextStyle sectionTitle;

  /// 13-14px/700 — cuerpo de tile con énfasis.
  final TextStyle bodyStrong;

  /// 13-14px/600 — cuerpo de tile.
  final TextStyle body;

  /// 11-12.5px/400-600 — metadatos (hora, día, etc.).
  final TextStyle metadata;

  /// 10-10.5px/400-700 — etiquetas diminutas (días de la semana, contadores).
  final TextStyle tinyLabel;

  static const SlateTypography standard = SlateTypography(
    screenTitle: TextStyle(
      fontFamily: fontFamily,
      fontSize: 24,
      fontWeight: FontWeight.w800,
    ),
    sectionTitle: TextStyle(
      fontFamily: fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w700,
    ),
    bodyStrong: TextStyle(
      fontFamily: fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w700,
    ),
    body: TextStyle(
      fontFamily: fontFamily,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
    metadata: TextStyle(
      fontFamily: fontFamily,
      fontSize: 12.5,
      fontWeight: FontWeight.w400,
    ),
    tinyLabel: TextStyle(
      fontFamily: fontFamily,
      fontSize: 10.5,
      fontWeight: FontWeight.w400,
    ),
  );

  /// Resuelve [SlateTypography] desde el [BuildContext] con fallback
  /// obligatorio, mismo criterio que [SlateColors.of].
  static SlateTypography of(BuildContext context) {
    return Theme.of(context).extension<SlateTypography>() ?? standard;
  }

  /// Construye el [TextTheme] de Material a partir de estos tokens y del
  /// color primario de texto vigente, para usarlo en la fábrica de
  /// [ThemeData] (`app_theme.dart`).
  TextTheme toTextTheme({
    required Color textPrimary,
    required Color textSecondary,
    required Color textTertiary,
  }) {
    return TextTheme(
      displayLarge: screenTitle.copyWith(color: textPrimary),
      displayMedium: screenTitle.copyWith(color: textPrimary),
      titleLarge: sectionTitle.copyWith(color: textPrimary),
      titleMedium: bodyStrong.copyWith(color: textPrimary),
      bodyLarge: body.copyWith(color: textPrimary),
      bodyMedium: body.copyWith(color: textSecondary),
      bodySmall: metadata.copyWith(color: textTertiary),
      labelLarge: bodyStrong.copyWith(color: textPrimary),
      labelMedium: metadata.copyWith(color: textSecondary),
      labelSmall: tinyLabel.copyWith(color: textTertiary),
    );
  }

  @override
  SlateTypography copyWith({
    TextStyle? screenTitle,
    TextStyle? sectionTitle,
    TextStyle? bodyStrong,
    TextStyle? body,
    TextStyle? metadata,
    TextStyle? tinyLabel,
  }) {
    return SlateTypography(
      screenTitle: screenTitle ?? this.screenTitle,
      sectionTitle: sectionTitle ?? this.sectionTitle,
      bodyStrong: bodyStrong ?? this.bodyStrong,
      body: body ?? this.body,
      metadata: metadata ?? this.metadata,
      tinyLabel: tinyLabel ?? this.tinyLabel,
    );
  }

  @override
  SlateTypography lerp(ThemeExtension<SlateTypography>? other, double t) {
    if (other is! SlateTypography) return this;
    return SlateTypography(
      screenTitle: TextStyle.lerp(screenTitle, other.screenTitle, t)!,
      sectionTitle: TextStyle.lerp(sectionTitle, other.sectionTitle, t)!,
      bodyStrong: TextStyle.lerp(bodyStrong, other.bodyStrong, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      metadata: TextStyle.lerp(metadata, other.metadata, t)!,
      tinyLabel: TextStyle.lerp(tinyLabel, other.tinyLabel, t)!,
    );
  }
}
