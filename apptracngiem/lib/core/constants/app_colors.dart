import 'package:flutter/material.dart';

class AppColors {
  // Backgrounds
  static const Color background = Color(0xFF0B0F19);
  static const Color backgroundSecondary = Color(0xFF111827);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color surfaceCard = Color(0xFF182234);

  // Glassmorphism
  static Color glassSurface = const Color(0xFF1E293B).withOpacity(0.55);
  static Color glassBorder = Colors.white.withOpacity(0.12);
  static Color glassBorderBright = const Color(0xFF06B6D4).withOpacity(0.4);

  // Neumorphism Shadows
  static const Color neuDarkShadow = Color(0xFF05070D);
  static const Color neuLightShadow = Color(0x18FFFFFF);

  // Accent Colors
  static const Color primary = Color(0xFF06B6D4); // Cyan
  static const Color primaryLight = Color(0xFF67E8F9);
  static const Color secondary = Color(0xFF10B981); // Emerald Green
  static const Color secondaryLight = Color(0xFF34D399);
  static const Color accentIndigo = Color(0xFF6366F1);

  // Status & RSSI Colors
  static const Color rssiGood = Color(0xFF10B981); // Emerald
  static const Color rssiWarning = Color(0xFFF59E0B); // Amber
  static const Color rssiCritical = Color(0xFFEF4444); // Crimson / Red
  static const Color rssiDisabled = Color(0xFF64748B);

  // Text Colors
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient emeraldGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warningGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient criticalGradient = LinearGradient(
    colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [
      Color(0x26FFFFFF),
      Color(0x0AFFFFFF),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
