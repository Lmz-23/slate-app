import 'package:flutter/material.dart';

enum AppThemeMode {
  dark,
  light,
  system;

  ThemeMode get themeMode {
    switch (this) {
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  String get displayName {
    switch (this) {
      case AppThemeMode.dark:
        return 'Oscuro';
      case AppThemeMode.light:
        return 'Claro';
      case AppThemeMode.system:
        return 'Sistema';
    }
  }
}