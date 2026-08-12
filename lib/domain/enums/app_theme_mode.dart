import 'package:flutter/material.dart';

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
