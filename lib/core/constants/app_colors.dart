import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF4F46E5);

  static const Color background = Color(0xFF0F0F0F);
  static const Color surface = Color(0xFF1A1A1A);
  static const Color surfaceLight = Color(0xFF262626);
  static const Color card = Color(0xFF1E1E1E);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA1A1AA);
  static const Color textTertiary = Color(0xFF71717A);

  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  static const Color streakFire = Color(0xFFFF6B35);
  static const Color streakGold = Color(0xFFFFD700);

  static const List<Color> categoryColors = [
    Color(0xFFEF4444),
    Color(0xFFF97316),
    Color(0xFFF59E0B),
    Color(0xFFEAB308),
    Color(0xFF84CC16),
    Color(0xFF22C55E),
    Color(0xFF10B981),
    Color(0xFF14B8A6),
    Color(0xFF06B6D4),
    Color(0xFF0EA5E9),
    Color(0xFF3B82F6),
    Color(0xFF6366F1),
    Color(0xFF8B5CF6),
    Color(0xFFA855F7),
    Color(0xFFD946EF),
    Color(0xFFEC4899),
    Color(0xFFF43F5E),
  ];

  static Color fromHex(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}