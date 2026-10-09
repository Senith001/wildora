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
    // Draw map-style background first
    _drawMapBackground(canvas, size);

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

  /// Draw realistic map-style background with land, water, roads, and greenspace
  void _drawMapBackground(Canvas canvas, Size size) {
    // Base land fill - derive from theme colors
    final isDark = theme.brightness == Brightness.dark;
    final landColor = isDark
        ? Color.alphaBlend(
            theme.colorScheme.surface.withOpacity(0.3),
            const Color(0xFF2A2F2A), // Dark desaturated slate
          )
        : Color.alphaBlend(
            theme.colorScheme.surfaceVariant.withOpacity(0.2),
            const Color(0xFFF0EFEA), // Warm off-white/beige
          );

    final landPaint = Paint()
      ..color = landColor
      ..style = PaintingStyle.fill;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), landPaint);

    // Water areas - muted blue tones
    final waterColor = isDark
        ? const Color(0xFF1E3A4A) // Desaturated dark blue
        : const Color(0xFFAFC9E8); // Muted light blue

    final waterPaint = Paint()
      ..color = waterColor
      ..style = PaintingStyle.fill;

    // Draw a diagonal river
    final riverPath = Path();
    riverPath.moveTo(0, size.height * 0.3);
    riverPath.quadraticBezierTo(
      size.width * 0.4,
      size.height * 0.2,
      size.width * 0.7,
      size.height * 0.4,
    );
    riverPath.quadraticBezierTo(
      size.width * 0.9,
      size.height * 0.5,
      size.width,
      size.height * 0.6,
    );
    riverPath.lineTo(size.width, size.height * 0.7);
    riverPath.quadraticBezierTo(
      size.width * 0.85,
      size.height * 0.6,
      size.width * 0.65,
      size.height * 0.5,
    );
    riverPath.quadraticBezierTo(
      size.width * 0.35,
      size.height * 0.3,
      0,
      size.height * 0.4,
    );
    riverPath.close();

    canvas.drawPath(riverPath, waterPaint);

    // Small lake in upper right
    final lakeCenter = Offset(size.width * 0.8, size.height * 0.15);
    final lakeRadius = size.width * 0.08;
    canvas.drawCircle(lakeCenter, lakeRadius, waterPaint);

    // Greenspace patches - muted green
    final greenColor = isDark
        ? const Color(0xFF1A3D1A) // Dark muted green
        : const Color(0xFFD4E6D4); // Light muted green

    final greenPaint = Paint()
      ..color = greenColor
      ..style = PaintingStyle.fill;

    // Park area in lower left
    final parkPath = Path();
    parkPath.addOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.2, size.height * 0.75),
        width: size.width * 0.25,
        height: size.height * 0.3,
      ),
    );
    canvas.drawPath(parkPath, greenPaint);

    // Small forest patch in upper left
    final forestPath = Path();
    forestPath.addOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.15, size.height * 0.2),
        width: size.width * 0.15,
        height: size.height * 0.2,
      ),
    );
    canvas.drawPath(forestPath, greenPaint);

    // Road network - theme-aware greys
    final majorRoadColor = theme.colorScheme.outline.withOpacity(0.4);
    final minorRoadColor = theme.colorScheme.outline.withOpacity(0.2);

    final majorRoadPaint = Paint()
      ..color = majorRoadColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final minorRoadPaint = Paint()
      ..color = minorRoadColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    // Major roads
    // Horizontal road
    canvas.drawLine(
      Offset(0, size.height * 0.6),
      Offset(size.width, size.height * 0.6),
      majorRoadPaint,
    );

    // Diagonal road
    canvas.drawLine(
      Offset(size.width * 0.1, size.height * 0.9),
      Offset(size.width * 0.9, size.height * 0.1),
      majorRoadPaint,
    );

    // Minor roads - grid pattern
    final gridPaint = Paint()
      ..color = minorRoadColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Vertical minor roads
    for (int i = 1; i < 4; i++) {
      final x = size.width * (i / 4);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // Horizontal minor roads
    for (int i = 1; i < 3; i++) {
      final y = size.height * (i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Curved connector road
    final connectorPath = Path();
    connectorPath.moveTo(size.width * 0.5, 0);
    connectorPath.quadraticBezierTo(
      size.width * 0.3,
      size.height * 0.3,
      size.width * 0.4,
      size.height * 0.6,
    );

    canvas.drawPath(connectorPath, minorRoadPaint);
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
