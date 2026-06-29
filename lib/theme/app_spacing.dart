import 'package:flutter/material.dart';

/// UPRISE Design System — Spacing & Shape Tokens
///
/// Import this file for consistent spacing, radius, and elevation.
/// Never hardcode pixel values in widget trees; use these constants.
abstract final class AppSpacing {
  // ── Spacing scale ─────────────────────────────────────────────
  /// 2 px — hairline separators, tiny icon gaps
  static const double xxs = 2;

  /// 4 px — icon-to-label gaps, inline gaps
  static const double xs = 4;

  /// 8 px — small component padding, tag spacing
  static const double sm = 8;

  /// 12 px — card internal gaps, list item spacing
  static const double md = 12;

  /// 16 px — standard screen horizontal padding
  static const double lg = 16;

  /// 20 px — section padding, modal internal padding
  static const double xl = 20;

  /// 24 px — between major sections
  static const double xxl = 24;

  /// 32 px — generous section separation
  static const double xxxl = 32;

  /// 48 px — hero spacing, large separators
  static const double huge = 48;

  // ── SizedBox helpers ──────────────────────────────────────────
  static const SizedBox gapXxs  = SizedBox(width: xxs, height: xxs);
  static const SizedBox gapXs   = SizedBox(width: xs,  height: xs);
  static const SizedBox gapSm   = SizedBox(width: sm,  height: sm);
  static const SizedBox gapMd   = SizedBox(width: md,  height: md);
  static const SizedBox gapLg   = SizedBox(width: lg,  height: lg);
  static const SizedBox gapXl   = SizedBox(width: xl,  height: xl);
  static const SizedBox gapXxl  = SizedBox(width: xxl, height: xxl);
  static const SizedBox gapXxxl = SizedBox(width: xxxl, height: xxxl);

  static const SizedBox hXxs  = SizedBox(width: xxs);
  static const SizedBox hXs   = SizedBox(width: xs);
  static const SizedBox hSm   = SizedBox(width: sm);
  static const SizedBox hMd   = SizedBox(width: md);
  static const SizedBox hLg   = SizedBox(width: lg);
  static const SizedBox hXl   = SizedBox(width: xl);
  static const SizedBox hXxl  = SizedBox(width: xxl);

  static const SizedBox vXxs  = SizedBox(height: xxs);
  static const SizedBox vXs   = SizedBox(height: xs);
  static const SizedBox vSm   = SizedBox(height: sm);
  static const SizedBox vMd   = SizedBox(height: md);
  static const SizedBox vLg   = SizedBox(height: lg);
  static const SizedBox vXl   = SizedBox(height: xl);
  static const SizedBox vXxl  = SizedBox(height: xxl);
  static const SizedBox vXxxl = SizedBox(height: xxxl);
  static const SizedBox vHuge = SizedBox(height: huge);

  // ── Edge insets ───────────────────────────────────────────────
  static const EdgeInsets paddingXs  = EdgeInsets.all(xs);
  static const EdgeInsets paddingSm  = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd  = EdgeInsets.all(md);
  static const EdgeInsets paddingLg  = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl  = EdgeInsets.all(xl);
  static const EdgeInsets paddingXxl = EdgeInsets.all(xxl);

  /// Standard horizontal screen padding.
  static const EdgeInsets screenH = EdgeInsets.symmetric(horizontal: lg);

  /// Standard vertical list/card padding.
  static const EdgeInsets listV = EdgeInsets.symmetric(vertical: md);

  /// Card content padding.
  static const EdgeInsets card = EdgeInsets.all(lg);

  /// Bottom-sheet content padding (no bottom — caller adds safe area).
  static const EdgeInsets sheet = EdgeInsets.fromLTRB(xl, md, xl, xxl);
}

// ── Border radius constants ──────────────────────────────────────
abstract final class AppRadius {
  /// 4 px — badge, tiny chip
  static const double xs = 4;

  /// 8 px — small card, tag
  static const double sm = 8;

  /// 12 px — standard card
  static const double md = 12;

  /// 16 px — large card, sheet header
  static const double lg = 16;

  /// 20 px — modal bottom sheet corners
  static const double xl = 20;

  /// 24 px — big hero cards
  static const double xxl = 24;

  /// 999 px — pill / fully rounded
  static const double pill = 999;

  // BorderRadius objects
  static const BorderRadius brXs   = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius brSm   = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius brMd   = BorderRadius.all(Radius.circular(md));
  static const BorderRadius brLg   = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius brXl   = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius brXxl  = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius brPill = BorderRadius.all(Radius.circular(pill));

  static const BorderRadius brTopXl = BorderRadius.vertical(
    top: Radius.circular(xl),
  );

  static const BorderRadius brTopXxl = BorderRadius.vertical(
    top: Radius.circular(xxl),
  );

  static const BorderRadius brBottomMd = BorderRadius.vertical(
    bottom: Radius.circular(md),
  );
}

// ── Elevation / shadow presets ───────────────────────────────────
abstract final class AppShadows {
  /// No shadow — flat surfaces.
  static const List<BoxShadow> none = [];

  /// Hairline — dividers, bottom nav bar.
  static const List<BoxShadow> xs = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];

  /// Card — standard card lift.
  static const List<BoxShadow> sm = [
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  /// Elevated card — announcements, event tiles.
  static const List<BoxShadow> md = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  /// Modal / bottom sheet.
  static const List<BoxShadow> lg = [
    BoxShadow(
      color: Color(0x1F000000),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  /// Orange glow — CTA buttons, active state.
  static const List<BoxShadow> orangeGlow = [
    BoxShadow(
      color: Color(0x40FF6B00),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  /// Dark elevated — top-level modals.
  static const List<BoxShadow> xl = [
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 40,
      offset: Offset(0, 16),
    ),
  ];
}
