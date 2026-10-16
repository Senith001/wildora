import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../data/models/alert.dart';

/// Real interactive map widget using flutter_map and OpenStreetMap tiles.
///
/// Displays the animal location with a marker and the high-risk zone as 
/// a circular overlay. Replaces the static CustomPaint ZoneMapPlaceholder 
/// with an actual interactive map.
class AlertLocationMap extends StatelessWidget {
  final AlertLocation animalLocation;
  final double zoneRadiusMeters;
  final String locationLabel;
  final bool isResolved;

  const AlertLocationMap({
    super.key,
    required this.animalLocation,
    required this.zoneRadiusMeters,
    required this.locationLabel,
    this.isResolved = false,
  });

  @override
  Widget build(BuildContext context) {
    final alertColors = Theme.of(context).extension<AlertColors>()!;
    final center = LatLng(animalLocation.latitude, animalLocation.longitude);
    // Muted styling for resolved alerts; red for active/responding.
    final markerColor = isResolved
        ? Theme.of(context).colorScheme.outline
        : alertColors.critical;

    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: 14,
          ),
          children: [
            // OpenStreetMap tiles
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.wildora.app',
            ),
            // High-risk zone circle
            CircleLayer(
              circles: [
                CircleMarker(
                  point: center,
                  radius: zoneRadiusMeters,
                  useRadiusInMeter: true,
                  color: markerColor.withOpacity(0.2),
                  borderColor: markerColor,
                  borderStrokeWidth: 2,
                ),
              ],
            ),
            // Animal location marker
            MarkerLayer(
              markers: [
                Marker(
                  point: center,
                  width: 40,
                  height: 40,
                  child: Icon(
                    Icons.location_on,
                    color: markerColor,
                    size: 40,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}