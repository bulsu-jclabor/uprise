import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// UPRISE Design System — Typography
///
/// All text styles are defined here using [GoogleFonts.beVietnamPro].
/// Use these via [Theme.of(context).textTheme] or the static helpers below.
///
/// Scale overview:
///   display   — Hero headings, app name (28–32 pt)
///   headline  — Section titles (22–26 pt)
///   title     — Card headings, dialog titles (16–20 pt)
///   body      — Content text (13–15 pt)
///   label     — Chips, badges, tabs, buttons (10–13 pt)
///   caption   — Timestamps, sub-labels, metadata (9–12 pt)
abstract final class AppTextStyles {
  // ── Base font family ─────────────────────────────────────────
  static String get _family => GoogleFonts.beVietnamPro().fontFamily!;

  // ── Display ──────────────────────────────────────────────────
  static TextStyle displayLarge = GoogleFonts.beVietnamPro(
    fontSize: 32,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.5,
    height: 1.1,
  );

  static TextStyle displayMedium = GoogleFonts.beVietnamPro(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    height: 1.15,
  );

  static TextStyle displaySmall = GoogleFonts.beVietnamPro(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.2,
  );

  // ── Headline ─────────────────────────────────────────────────
  static TextStyle headlineLarge = GoogleFonts.beVietnamPro(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );

  static TextStyle headlineMedium = GoogleFonts.beVietnamPro(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );

  static TextStyle headlineSmall = GoogleFonts.beVietnamPro(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  // ── Title ────────────────────────────────────────────────────
  static TextStyle titleLarge = GoogleFonts.beVietnamPro(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.35,
  );

  static TextStyle titleMedium = GoogleFonts.beVietnamPro(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static TextStyle titleSmall = GoogleFonts.beVietnamPro(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  // ── Body ─────────────────────────────────────────────────────
  static TextStyle bodyLarge = GoogleFonts.beVietnamPro(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.6,
  );

  static TextStyle bodyMedium = GoogleFonts.beVietnamPro(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.55,
  );

  static TextStyle bodySmall = GoogleFonts.beVietnamPro(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  // ── Label ────────────────────────────────────────────────────
  static TextStyle labelLarge = GoogleFonts.beVietnamPro(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  static TextStyle labelMedium = GoogleFonts.beVietnamPro(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );

  static TextStyle labelSmall = GoogleFonts.beVietnamPro(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  // ── Caption ──────────────────────────────────────────────────
  static TextStyle captionLarge = GoogleFonts.beVietnamPro(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static TextStyle captionMedium = GoogleFonts.beVietnamPro(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static TextStyle captionSmall = GoogleFonts.beVietnamPro(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.3,
  );

  // ── Badge / chip overline ────────────────────────────────────
  static TextStyle overline = GoogleFonts.beVietnamPro(
    fontSize: 9,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
  );

  // ── Build a Material TextTheme ───────────────────────────────
  static TextTheme buildTextTheme({required bool dark}) {
    final base = dark ? Colors.white : const Color(0xFF1A202C);
    final muted = dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return TextTheme(
      displayLarge:  displayLarge.copyWith(color: base),
      displayMedium: displayMedium.copyWith(color: base),
      displaySmall:  displaySmall.copyWith(color: base),

      headlineLarge:  headlineLarge.copyWith(color: base),
      headlineMedium: headlineMedium.copyWith(color: base),
      headlineSmall:  headlineSmall.copyWith(color: base),

      titleLarge:  titleLarge.copyWith(color: base),
      titleMedium: titleMedium.copyWith(color: base),
      titleSmall:  titleSmall.copyWith(color: base),

      bodyLarge:  bodyLarge.copyWith(color: base),
      bodyMedium: bodyMedium.copyWith(color: base),
      bodySmall:  bodySmall.copyWith(color: muted),

      labelLarge:  labelLarge.copyWith(color: base),
      labelMedium: labelMedium.copyWith(color: muted),
      labelSmall:  labelSmall.copyWith(color: muted),
    );
  }
}
