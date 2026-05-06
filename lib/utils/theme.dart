// lib/utils/theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color primaryOrange = Color(0xFFFF6B35);  // Warm orange from logo
const Color primaryBrown = Color(0xFF8B5A2B);   // Brown from gear
const Color secondaryOrange = Color(0xFFFF8C42);
const Color darkBrown = Color(0xFF5C3A21);
const Color backgroundColor = Color(0xFFFEF7E8);
const Color textDark = Color(0xFF2C1810);
const Color textLight = Color(0xFFF5E6D3);

ThemeData appTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: primaryOrange,
  colorScheme: const ColorScheme.light(
    primary: primaryOrange,
    secondary: secondaryOrange,
    surface: Colors.white,
    background: backgroundColor,
  ),
  scaffoldBackgroundColor: backgroundColor,
  fontFamily: GoogleFonts.poppins().fontFamily,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: textDark,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: textDark,
    ),
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: Colors.white,
    selectedItemColor: primaryOrange,
    unselectedItemColor: Colors.grey,
    type: BottomNavigationBarType.fixed,
    elevation: 8,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: primaryOrange, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: primaryOrange,
      foregroundColor: Colors.white,
      minimumSize: const Size(double.infinity, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
);