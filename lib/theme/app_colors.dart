import 'package:flutter/material.dart';

/// UPRISE Design System — Color Palette
///
/// All colors are defined here. No screen should reference
/// [Colors.orange], [Colors.white], or [Colors.black] directly.
/// Instead, use [Theme.of(context).colorScheme] or the constants
/// below for one-off values that aren't covered by the scheme.
abstract final class UpriseColors {
  // ── Brand / Primary ──────────────────────────────────────────
  /// The signature UPRISE orange — used for CTAs, active states, and accents.
  static const Color primaryOrange = Color(0xFFFF6B00);

  /// A slightly lighter orange for hover / focus rings, gradients.
  static const Color primaryOrangeLight = Color(0xFFFF8C42);

  /// Muted orange tint, used for chip backgrounds and subtle highlights.
  static const Color primaryOrangeSurface = Color(0xFFFFEDD5);

  // ── Secondary / Accent ───────────────────────────────────────
  static const Color accentAmber = Color(0xFFFF9800);
  static const Color accentDeepOrange = Color(0xFFEA580C);

  // ── Semantic ─────────────────────────────────────────────────
  static const Color success = Color(0xFF059669);
  static const Color successSurface = Color(0xFFECFDF5);

  static const Color warning = Color(0xFFD97706);
  static const Color warningSurface = Color(0xFFFFF7ED);

  static const Color error = Color(0xFFDC2626);
  static const Color errorSurface = Color(0xFFFEF2F2);

  static const Color info = Color(0xFF2563EB);
  static const Color infoSurface = Color(0xFFEFF6FF);

  // ── Light theme neutrals ─────────────────────────────────────
  static const Color lightBackground = Color(0xFFF8F9FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF0F2F5);
  static const Color lightBorder = Color(0xFFE8ECF0);
  static const Color lightBorderSoft = Color(0xFFF0F2F5);

  static const Color lightOnBackground = Color(0xFF1A202C);
  static const Color lightOnSurface = Color(0xFF1A202C);
  static const Color lightOnSurfaceVariant = Color(0xFF64748B);
  static const Color lightOnSurfaceMuted = Color(0xFF9AA5B4);

  // ── Dark theme neutrals ──────────────────────────────────────
  static const Color darkBackground = Color(0xFF0F1117);
  static const Color darkSurface = Color(0xFF1A1D27);
  static const Color darkSurfaceVariant = Color(0xFF222533);
  static const Color darkBorder = Color(0xFF2D3143);
  static const Color darkBorderSoft = Color(0xFF252838);

  static const Color darkOnBackground = Color(0xFFF1F5F9);
  static const Color darkOnSurface = Color(0xFFE2E8F0);
  static const Color darkOnSurfaceVariant = Color(0xFF94A3B8);
  static const Color darkOnSurfaceMuted = Color(0xFF64748B);

  // ── Gradients ────────────────────────────────────────────────
  static const LinearGradient brandGradient = LinearGradient(
    colors: [primaryOrange, primaryOrangeLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient brandGradientVertical = LinearGradient(
    colors: [primaryOrange, accentDeepOrange],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient darkOverlay = LinearGradient(
    colors: [Colors.transparent, Color(0xB3000000)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── Broadcast channel presets ────────────────────────────────
  static const Map<String, List<Color>> broadcastThemes = {
    'orange': [Color(0xFFEA580C), Color(0xFFF97316)],
    'blue':   [Color(0xFF2563EB), Color(0xFF3B82F6)],
    'green':  [Color(0xFF059669), Color(0xFF10B981)],
    'purple': [Color(0xFF7C3AED), Color(0xFFA78BFA)],
    'pink':   [Color(0xFFDB2777), Color(0xFFF472B6)],
    'teal':   [Color(0xFF0D9488), Color(0xFF2DD4BF)],
  };

  static List<Color> broadcastThemeColors(String? id) =>
      broadcastThemes[id] ?? broadcastThemes['orange']!;

  // ── Convenience: shadow ──────────────────────────────────────
  static Color shadowLight = const Color(0x14000000); // 8%
  static Color shadowMedium = const Color(0x1F000000); // 12%
  static Color shadowStrong = const Color(0x33000000); // 20%
}

// lib/widgets/student/app_colors.dart

/// Alias to match the web naming conventions.
/// Maps UpriseColors (used across web & mobile) to UpriseColors.
abstract final class UpriseColorAliases {
  // ── Brand / Primary ──────────────────────────────────────────
  static const Color primaryDark = UpriseColors.primaryOrange;
  static const Color primaryLight = UpriseColors.primaryOrangeLight;
  static const Color primarySurface = UpriseColors.primaryOrangeSurface;

  // ── Secondary / Accent ───────────────────────────────────────
  static const Color accent = UpriseColors.accentAmber;
  static const Color accentDeepOrange = UpriseColors.accentDeepOrange;

  // ── Semantic ─────────────────────────────────────────────────
  static const Color error = UpriseColors.error;
  static const Color success = UpriseColors.success;
  static const Color warning = UpriseColors.warning;
  static const Color info = UpriseColors.info;

  // ── Light theme neutrals ─────────────────────────────────────
  static const Color lightGray = UpriseColors.lightBackground;
  static const Color charcoal = UpriseColors.lightOnBackground;
  static const Color white = UpriseColors.lightSurface;

  // ── Dark theme neutrals ─────────────────────────────────────
  static const Color darkSurface = UpriseColors.darkSurface;
  static const Color darkBackground = UpriseColors.darkBackground;
}
