import 'package:flutter/material.dart';

/// Centralized theme configuration for Wildora app.
///
/// Provides both light and dark theme variants using the existing
/// deepPurple seed color to maintain visual consistency.
class AppTheme {
  static ThemeData light() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: Brightness.light,
      ),
      extensions: [AlertColors.light],
    );
  }

  static ThemeData dark() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: Brightness.dark,
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

  const AlertColors({
    required this.critical,
    required this.onCritical,
    required this.signal,
  });

  static const AlertColors light = AlertColors(
    critical: Color(0xFFD32F2F), // Red for critical alerts in light mode
    onCritical: Color(0xFFFFFFFF), // White text on red background
    signal: Color(0xFF1976D2), // Blue for signal/info in light mode
  );

  static const AlertColors dark = AlertColors(
    critical: Color(0xFFEF5350), // Lighter red for critical alerts in dark mode
    onCritical: Color(0xFF000000), // Black text on lighter red background
    signal: Color(0xFF42A5F5), // Lighter blue for signal/info in dark mode
  );

  @override
  ThemeExtension<AlertColors> copyWith({
    Color? critical,
    Color? onCritical,
    Color? signal,
  }) {
    return AlertColors(
      critical: critical ?? this.critical,
      onCritical: onCritical ?? this.onCritical,
      signal: signal ?? this.signal,
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
    );
  }
}
