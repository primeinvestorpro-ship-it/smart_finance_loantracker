import 'package:flutter/material.dart';

class AppTheme {
  // Brand Palette: Dark Navy & Emerald Accent for Modern Fintech Feel
  static const Color primaryDark = Color(0xFF0F172A); // Slate Navy
  static const Color surfaceDark = Color(0xFF1E293B); // Card Dark
  static const Color accentGreen = Color(0xFF10B981); // Emerald Teal
  static const Color accentCyan = Color(0xFF06B6D4);
  static const Color alertRed = Color(0xFFEF4444);
  static const Color alertOrange = Color(0xFFF59E0B);
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Colors.white;

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: backgroundLight,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF0F172A),
      secondary: accentGreen,
      surface: surfaceLight,
      error: alertRed,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: backgroundLight,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Color(0xFF0F172A),
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(color: Color(0xFF0F172A)),
    ),
    cardTheme: CardThemeData(
      color: surfaceLight,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF090D16),
    colorScheme: const ColorScheme.dark(
      primary: accentGreen,
      secondary: accentCyan,
      surface: surfaceDark,
      error: alertRed,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF090D16),
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),
    cardTheme: CardThemeData(
      color: surfaceDark,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
