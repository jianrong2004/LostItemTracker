import 'package:flutter/material.dart';

/// Shared visual language for the Admin module (slate / teal, calm “console” feel).
abstract final class AdminTheme {
  static const Color primary = Color(0xFF1E3A5F);
  static const Color primaryLight = Color(0xFF2D5A87);
  static const Color accent = Color(0xFF0D9488);

  static const Color scaffoldBackground = Color(0xFFF8FAFC);
  static const Color cardSurface = Colors.white;
  static const Color border = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);

  /// Subtle grid + high-contrast tooltip for charts (avoids dark-grey / neon text).
  static const Color chartGridLine = Color(0xFFE2E8F0);
  static const Color chartTooltipBg = Color(0xFFFFFFFF);

  /// Distinct, bright bar colors on white (cycles when there are many categories).
  static const List<Color> chartBarPalette = [
    Color(0xFF6366F1),
    Color(0xFF0EA5E9),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
  ];

  static const double radiusL = 16;
  static const double radiusM = 12;

  /// KPI / stat tints (used for icon & accent strip only; cards stay neutral).
  static const Color statLost = Color(0xFFBE123C);
  static const Color statFound = Color(0xFF059669);
  static const Color statUsers = Color(0xFF2563EB);
  static const Color statClaims = Color(0xFFEA580C);
  static const Color statResolved = Color(0xFFD97706);

  static LinearGradient get headerGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primary, primaryLight],
      );

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ];

  static BoxDecoration cardDecoration() => BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(radiusM),
        border: Border.all(color: border),
        boxShadow: cardShadow,
      );

  static TextStyle sectionTitle() => const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: -0.3,
      );

  static TextStyle sectionGroupLabel() => const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: textSecondary,
        letterSpacing: 0.6,
      );
}
