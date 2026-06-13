import 'package:flutter/material.dart';

/// Brand and surface tokens for RetailPilot Employee app.
abstract final class AppColors {
  static const emerald = Color(0xFF059669);
  static const emeraldLight = Color(0xFF10B981);
  static const emeraldDark = Color(0xFF047857);
  static const indigo = Color(0xFF6366F1);
  static const indigoLight = Color(0xFF818CF8);

  static const slate950 = Color(0xFF020617);
  static const slate900 = Color(0xFF0F172A);
  static const slate800 = Color(0xFF1E293B);
  static const slate700 = Color(0xFF334155);
  static const slate500 = Color(0xFF64748B);
  static const slate400 = Color(0xFF94A3B8);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate50 = Color(0xFFF8FAFC);

  static const error = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
  static const success = Color(0xFF10B981);

  static const lightSeed = emerald;
  static const darkSeed = emeraldLight;

  /// Home header — slate base with a soft teal accent (not all-green).
  static List<Color> get heroGradientLight => [
        const Color(0xFF475569),
        const Color(0xFF64748B),
        const Color(0xFF0E7490),
      ];

  static List<Color> get heroGradientDark => [
        slate950,
        slate800,
        const Color(0xFF155E75).withValues(alpha: 0.72),
      ];

  static const homeAccentTeal = Color(0xFF14B8A6);
  static const homeAccentSky = Color(0xFF38BDF8);
  static const homeAccentAmber = Color(0xFFF59E0B);
  static const homeAccentViolet = Color(0xFF8B5CF6);
  static const homeAccentRose = Color(0xFFF472B6);

  static List<Color> get cardAccentGradient => [
        emerald.withValues(alpha: 0.12),
        indigo.withValues(alpha: 0.08),
      ];
}
