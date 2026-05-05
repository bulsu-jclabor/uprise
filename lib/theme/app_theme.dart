// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class UpriseColors {
  // Official UPRISE Color Palette (Figure 53)
  static const Color primaryDark = Color(0xFFBE4700);   // deep orange/brown – stability, technology
  static const Color primaryLight = Color(0xFFD47A00);  // warm orange – passion, enthusiasm
  static const Color accent = Color(0xFFDA6937);       // secondary accent – growth, approachable
  static const Color white = Color(0xFFFFFFFF);         // clean background
  
  // Supporting neutrals (from your design system)
  static const Color charcoal = Color(0xFF1F2937);
  static const Color darkGray = Color(0xFF6B7280);
  static const Color mediumGray = Color(0xFFE5E7EB);
  static const Color lightGray = Color(0xFFF9FAFB);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
}

class UpriseTheme {
  static ThemeData lightTheme = ThemeData(
    // Set primary color for general theming
    primaryColor: UpriseColors.primaryDark,
    // Use Be Vietnam Pro as the default font for the whole app
    fontFamily: GoogleFonts.beVietnamPro().fontFamily,
    scaffoldBackgroundColor: UpriseColors.lightGray,
    appBarTheme: AppBarTheme(
      backgroundColor: UpriseColors.white,
      elevation: 0,
      // Use Be Vietnam Pro for AppBar title
      titleTextStyle: GoogleFonts.beVietnamPro(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: UpriseColors.charcoal,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: UpriseColors.primaryDark),
        borderRadius: BorderRadius.circular(8),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: UpriseColors.primaryDark,
        foregroundColor: UpriseColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: UpriseColors.primaryDark),
    ),
    colorScheme: ColorScheme.light(
      primary: UpriseColors.primaryDark,
      secondary: UpriseColors.primaryLight,
      tertiary: UpriseColors.accent,
      background: UpriseColors.lightGray,
      surface: UpriseColors.white,
      error: UpriseColors.error,
    ),
  );
}