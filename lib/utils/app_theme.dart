import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFFF4F7FB),
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF1D4ED8),
      secondary: Color(0xFF0F766E),
      tertiary: Color(0xFFF97316),
      surface: Color(0xFFF8FAFC),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Color(0xFF0F172A),
      outline: Color(0xFFD7E0EA),
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -0.8, color: Color(0xFF0F172A)),
      headlineSmall: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: -0.6, color: Color(0xFF0F172A)),
      titleLarge: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
      bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: Color(0xFF334155)),
      bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF475569)),
      bodySmall: TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF64748B)),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      foregroundColor: Color(0xFF0F172A),
      titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      color: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFD7E0EA)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFD7E0EA)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFF1D4ED8), width: 1.4),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF0F172A),
      contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0B1220),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF60A5FA),
      secondary: Color(0xFF34D399),
      tertiary: Color(0xFFFB923C),
      surface: Color(0xFF0F172A),
      onPrimary: Color(0xFF0B1220),
      onSecondary: Color(0xFF0B1220),
      onSurface: Color(0xFFE5E7EB),
      outline: Color(0xFF233046),
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -0.8, color: Color(0xFFE5E7EB)),
      headlineSmall: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: -0.6, color: Color(0xFFE5E7EB)),
      titleLarge: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Color(0xFFE5E7EB)),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFE5E7EB)),
      bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: Color(0xFFCBD5E1)),
      bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: Color(0xFFB6C2D1)),
      bodySmall: TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF94A3B8)),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      foregroundColor: Color(0xFFE5E7EB),
      titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFFE5E7EB)),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      color: const Color(0xFF0F172A),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF0F172A),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFF233046)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFF233046)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFF60A5FA), width: 1.4),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF111827),
      contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}