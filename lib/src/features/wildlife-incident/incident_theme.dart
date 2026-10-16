import 'package:flutter/material.dart';

/// The incident design uses light surfaces regardless of the homepage theme.
ThemeData incidentTheme() {
  const green = Color(0xFF10583F);
  final scheme = ColorScheme.fromSeed(
    seedColor: green,
    brightness: Brightness.light,
  ).copyWith(primary: green, onPrimary: Colors.white);
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF2F6F3),
    appBarTheme: const AppBarTheme(
      backgroundColor: green,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: green,
      unselectedItemColor: Color(0xFF61736C),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(),
    ),
  );
}
