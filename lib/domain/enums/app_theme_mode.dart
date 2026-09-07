import 'package:flutter/material.dart';

// DECISIÓN de producto: NO existe el modo 'system' (seguir el tema del
// dispositivo). Slate es "dark-first": el oscuro es la identidad de la app y
// el claro una elección explícita del usuario.
//
// Los registros antiguos pueden guardar el ordinal 2 (antiguo
// `AppThemeMode.system`), que ya no existe en este enum. La lectura lo
// interpreta como `dark` sin crash en
// `UserSettingsAdapter._themeModeFromStoredIndex`.
enum AppThemeMode {
  dark,
  light;

  ThemeMode get themeMode {
    switch (this) {
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.light:
        return ThemeMode.light;
    }
  }

  String get displayName {
    switch (this) {
      case AppThemeMode.dark:
        return 'Oscuro';
      case AppThemeMode.light:
        return 'Claro';
    }
  }
}
