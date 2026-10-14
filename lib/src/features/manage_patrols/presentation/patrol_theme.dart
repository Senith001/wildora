import 'package:flutter/material.dart';

/// Centralized design system and theme constants for the Wildora Field Operations
/// and Manage Patrols module.
///
/// Features a cohesive conservation palette:
/// - Forest deep: `#1B4332`, `#2D6A4F`, `#40916C`
/// - Warm off-white background: `#F8F9F5`
/// - Charcoal typography: `#1F241F`, `#3E4A3E`
/// - Restrained operational amber: `#D97706`, `#B45309`
class PatrolTheme {
  // Brand Forest Greens
  static const Color forestDeep = Color(0xFF1B4332);
  static const Color forestPrimary = Color(0xFF2D6A4F);
  static const Color forestMedium = Color(0xFF40916C);
  static const Color forestLight = Color(0xFF52B788);
  static const Color forestSurface = Color(0xFFEBF5EE);
  static const Color forestBorder = Color(0xFFD0E6D8);

  // Warm Neutrals & Charcoal
  static const Color background = Color(0xFFF7F9F5);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFF1F5EE);
  static const Color charcoal = Color(0xFF1B241C);
  static const Color charcoalMuted = Color(0xFF465348);
  static const Color charcoalSubtle = Color(0xFF718274);
  static const Color borderLight = Color(0xFFE3E9E2);

  // Operational Accents & Statuses
  static const Color amber = Color(0xFFD97706);
  static const Color amberDark = Color(0xFFB45309);
  static const Color amberSurface = Color(0xFFFEF3C7);
  static const Color amberBorder = Color(0xFFFDE68A);

  static const Color success = Color(0xFF2E7D32);
  static const Color successSurface = Color(0xFFE8F5E9);
  static const Color successBorder = Color(0xFFC8E6C9);

  static const Color error = Color(0xFFDC2626);
  static const Color errorSurface = Color(0xFFFEE2E2);
  static const Color errorBorder = Color(0xFFFECACA);

  static const Color infoBlue = Color(0xFF2563EB);
  static const Color infoSurface = Color(0xFFEFF6FF);

  // Border Radii
  static const BorderRadius radiusSm = BorderRadius.all(Radius.circular(8));
  static const BorderRadius radiusMd = BorderRadius.all(Radius.circular(14));
  static const BorderRadius radiusLg = BorderRadius.all(Radius.circular(20));
  static const BorderRadius radiusFull = BorderRadius.all(Radius.circular(999));

  // Box Shadows
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 10,
      offset: Offset(0, 3),
    ),
  ];

  static const List<BoxShadow> cardShadowHover = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 16,
      offset: Offset(0, 6),
    ),
  ];

  /// Shared container decoration for operational cards.
  static BoxDecoration cardDecoration({
    Color? backgroundColor,
    Color? borderColor,
    BorderRadius? borderRadius,
  }) {
    return BoxDecoration(
      color: backgroundColor ?? surfaceCard,
      borderRadius: borderRadius ?? radiusMd,
      border: Border.all(color: borderColor ?? borderLight, width: 1.2),
      boxShadow: cardShadow,
    );
  }

  /// Max layout constraint width for responsiveness across phones, tablets,
  /// and wide desktop viewports.
  static const double maxContentWidth = 920.0;
}
