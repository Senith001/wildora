import 'package:flutter/material.dart';

import 'brand_colors.dart';

/// Centralized theme configuration for Wildora app.
///
/// Provides both light and dark theme variants using a conservation green
/// seed color to maintain visual consistency with the brand identity.
class AppTheme {
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2E7D32), // Conservation green
      brightness: Brightness.light,
    );

    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: kBrandBackgroundLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: kBrandHeaderGreen,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 2,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        surfaceTintColor: colorScheme.surfaceTint,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      extensions: [AlertColors.light],
    );
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2E7D32), // Conservation green
      brightness: Brightness.dark,
    );

    return ThemeData(
      colorScheme: colorScheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: kBrandHeaderGreen,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 2,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        surfaceTintColor: colorScheme.surfaceTint,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      extensions: [AlertColors.dark],
    );
  }
}

/// Theme extension for alert-specific colors that adapt to light/dark themes.
///
/// Provides semantic colors for critical alerts, signals, and other
/// alert UI elements that need to maintain readability across themes.
class AlertColors extends ThemeExtension<AlertColors> {
  final Color critical;
  final Color onCritical;
  final Color signal;

  // Medium severity (orange) and Low severity (amber/yellow) tokens.
  final Color mediumSeverity;
  final Color onMediumSeverity;
  final Color lowSeverity;
  final Color onLowSeverity;

  const AlertColors({
    required this.critical,
    required this.onCritical,
    required this.signal,
    required this.mediumSeverity,
    required this.onMediumSeverity,
    required this.lowSeverity,
    required this.onLowSeverity,
  });

  static const AlertColors light = AlertColors(
    critical: Color(0xFFD32F2F), // Red for critical alerts in light mode
    onCritical: Color(0xFFFFFFFF), // White text on red background
    signal: Color(0xFF1976D2), // Blue for signal/info in light mode
    mediumSeverity: Color(0xFFEF6C00), // Orange for Medium in light mode
    onMediumSeverity: Color(0xFFFFFFFF), // White text on orange
    lowSeverity: Color(0xFFF9A825), // Amber-yellow for Low in light mode
    onLowSeverity: Color(0xFF000000), // Black text on amber for readability
  );

  static const AlertColors dark = AlertColors(
    critical: Color(0xFFEF5350), // Lighter red for critical alerts in dark mode
    onCritical: Color(0xFF000000), // Black text on lighter red background
    signal: Color(0xFF42A5F5), // Lighter blue for signal/info in dark mode
    mediumSeverity: Color(0xFFFF9800), // Lighter orange for Medium in dark mode
    onMediumSeverity: Color(0xFF000000), // Black text on lighter orange
    lowSeverity: Color(0xFFFFCA28), // Lighter amber for Low in dark mode
    onLowSeverity: Color(0xFF000000), // Black text on amber for readability
  );

  @override
  ThemeExtension<AlertColors> copyWith({
    Color? critical,
    Color? onCritical,
    Color? signal,
    Color? mediumSeverity,
    Color? onMediumSeverity,
    Color? lowSeverity,
    Color? onLowSeverity,
  }) {
    return AlertColors(
      critical: critical ?? this.critical,
      onCritical: onCritical ?? this.onCritical,
      signal: signal ?? this.signal,
      mediumSeverity: mediumSeverity ?? this.mediumSeverity,
      onMediumSeverity: onMediumSeverity ?? this.onMediumSeverity,
      lowSeverity: lowSeverity ?? this.lowSeverity,
      onLowSeverity: onLowSeverity ?? this.onLowSeverity,
    );
  }

  @override
  ThemeExtension<AlertColors> lerp(
    covariant ThemeExtension<AlertColors>? other,
    double t,
  ) {
    if (other is! AlertColors) return this;

    return AlertColors(
      critical: Color.lerp(critical, other.critical, t)!,
      onCritical: Color.lerp(onCritical, other.onCritical, t)!,
      signal: Color.lerp(signal, other.signal, t)!,
      mediumSeverity: Color.lerp(mediumSeverity, other.mediumSeverity, t)!,
      onMediumSeverity: Color.lerp(
        onMediumSeverity,
        other.onMediumSeverity,
        t,
      )!,
      lowSeverity: Color.lerp(lowSeverity, other.lowSeverity, t)!,
      onLowSeverity: Color.lerp(onLowSeverity, other.onLowSeverity, t)!,
    );
  }
}
