import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../data/models/alert.dart';

/// CustomPaint placeholder for zone map showing circular zone and animal pin.
///
/// Features:
/// - Green-ish background representing terrain
/// - Red translucent circle showing high-risk zone boundary
/// - Red pin marker showing animal position
/// - Legend explaining map elements
/// - Theme-aware colors that work in both light and dark modes
/// - No google_maps_flutter dependency as per plan decision
class ZoneMapPlaceholder extends StatelessWidget {
  final AlertLocation zoneCenter;
  final AlertLocation animalLocation;
  final double zoneRadiusMeters;
  final String locationLabel;

  const ZoneMapPlaceholder({
    super.key,
    required this.zoneCenter,
    required this.animalLocation,
    required this.zoneRadiusMeters,
    required this.locationLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CustomPaint(
          painter: _ZoneMapPainter(
            zoneCenter: zoneCenter,
            animalLocation: animalLocation,
            zoneRadiusMeters: zoneRadiusMeters,
            locationLabel: locationLabel,
            theme: Theme.of(context),
            alertColors: Theme.of(context).extension<AlertColors>()!,
          ),
          child: Container(
            height: 200,
            width: double.infinity,
            alignment: Alignment.bottomRight,
            padding: const EdgeInsets.all(8),
            child: _buildLegend(context),
          ),
        ),
      ),
    );
  }

  /// Build legend explaining map elements
  Widget _buildLegend(BuildContext context) {
    final alertColors = Theme.of(context).extension<AlertColors>()!;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLegendItem(
            context,
            alertColors.critical.withOpacity(0.3),
            'High-Risk Zone',
            Icons.circle,
          ),
          const SizedBox(height: 4),
          _buildLegendItem(
            context,
            alertColors.critical,
            'Animal Position',
            Icons.location_on,
          ),
        ],
      ),
    );
  }

  /// Build individual legend item
  Widget _buildLegendItem(
    BuildContext context,
    Color color,
    String label,
    IconData icon,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

/// Custom painter for drawing the zone map
class _ZoneMapPainter extends CustomPainter {
  final AlertLocation zoneCenter;
  final AlertLocation animalLocation;
  final double zoneRadiusMeters;
  final String locationLabel;
  final ThemeData theme;
  final AlertColors alertColors;

  const _ZoneMapPainter({
    required this.zoneCenter,
    required this.animalLocation,
    required this.zoneRadiusMeters,
    required this.locationLabel,
    required this.theme,
    required this.alertColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Background terrain color (theme-aware green-ish)
    final backgroundPaint = Paint()
      ..color = _getTerrainColor()
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      backgroundPaint,
    );

    // Calculate center point and scale
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final scale = _calculateScale(size);

    // Draw zone circle
    _drawZoneCircle(canvas, centerX, centerY, scale);

    // Draw animal pin
    _drawAnimalPin(canvas, centerX, centerY, scale, size);

    // Draw location label
    _drawLocationLabel(canvas, size);
  }

  /// Get terrain background color based on theme
  Color _getTerrainColor() {
    final isDark = theme.brightness == Brightness.dark;
    return isDark
        ? const Color(0xFF2E4F2E) // Dark green for dark theme
        : const Color(0xFFE8F5E8); // Light green for light theme
  }

  /// Calculate scale factor to fit zone within canvas
  double _calculateScale(Size size) {
    final minDimension = math.min(size.width, size.height);
    // Scale so zone circle takes up about 60% of available space
    return (minDimension * 0.6) / (zoneRadiusMeters * 2);
  }

  /// Draw the high-risk zone circle
  void _drawZoneCircle(
    Canvas canvas,
    double centerX,
    double centerY,
    double scale,
  ) {
    final zoneRadius = zoneRadiusMeters * scale;

    // Zone circle fill
    final zonePaint = Paint()
      ..color = alertColors.critical.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(centerX, centerY), zoneRadius, zonePaint);

    // Zone circle border
    final zoneBorderPaint = Paint()
      ..color = alertColors.critical.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(Offset(centerX, centerY), zoneRadius, zoneBorderPaint);
  }

  /// Draw the animal position pin
  void _drawAnimalPin(
    Canvas canvas,
    double centerX,
    double centerY,
    double scale,
    Size size,
  ) {
    // For simplicity, assume animal is at zone center for demo
    // In real implementation, this would use actual lat/lng offset
    final pinX = centerX;
    final pinY = centerY;

    // Pin shadow
    final shadowPaint = Paint()
      ..color = theme.colorScheme.shadow.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(pinX + 1, pinY + 1), 8, shadowPaint);

    // Pin background
    final pinPaint = Paint()
      ..color = alertColors.critical
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(pinX, pinY), 8, pinPaint);

    // Pin border
    final pinBorderPaint = Paint()
      ..color = theme.colorScheme.onPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(Offset(pinX, pinY), 8, pinBorderPaint);

    // Pin center dot
    final pinCenterPaint = Paint()
      ..color = theme.colorScheme.onPrimary
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(pinX, pinY), 3, pinCenterPaint);
  }

  /// Draw location label at top of canvas
  void _drawLocationLabel(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: locationLabel,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              offset: const Offset(0, 1),
              blurRadius: 2,
              color: theme.colorScheme.surface.withOpacity(0.8),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    // Center the text horizontally at top
    final textX = (size.width - textPainter.width) / 2;
    const textY = 12.0;

    // Draw background for text
    final backgroundRect = Rect.fromLTWH(
      textX - 8,
      textY - 4,
      textPainter.width + 16,
      textPainter.height + 8,
    );

    final backgroundPaint = Paint()
      ..color = theme.colorScheme.surface.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(backgroundRect, const Radius.circular(4)),
      backgroundPaint,
    );

    // Draw text
    textPainter.paint(canvas, Offset(textX, textY));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is! _ZoneMapPainter ||
        oldDelegate.zoneCenter != zoneCenter ||
        oldDelegate.animalLocation != animalLocation ||
        oldDelegate.zoneRadiusMeters != zoneRadiusMeters ||
        oldDelegate.locationLabel != locationLabel ||
        oldDelegate.theme != theme ||
        oldDelegate.alertColors != alertColors;
  }
}
