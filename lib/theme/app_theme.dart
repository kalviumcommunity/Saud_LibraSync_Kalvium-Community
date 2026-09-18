import 'package:flutter/material.dart';

/// Centralized theme configuration for LibraSync.
///
/// All colors, typography, and component styles are defined here so they
/// can be referenced consistently throughout the application.
class AppTheme {
  AppTheme._(); // Prevent instantiation.

  // ─── Brand Colors ───────────────────────────────────────────────────
  static const Color _primarySeed = Color(0xFF1565C0); // Deep library blue

  // ─── Light Theme ────────────────────────────────────────────────────
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorSchemeSeed: _primarySeed,

    // AppBar
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
    ),

    // Cards
    cardTheme: CardThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
    ),

    // Floating Action Button
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      elevation: 2,
    ),

    // Input fields (for future use)
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );

  // ─── Dark Theme ─────────────────────────────────────────────────────
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorSchemeSeed: _primarySeed,

    // AppBar
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
    ),

    // Cards
    cardTheme: CardThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
    ),

    // Floating Action Button
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      elevation: 2,
    ),

    // Input fields (for future use)
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );
}
