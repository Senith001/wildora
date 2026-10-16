import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'incident_widgets.dart';

/// Free OpenStreetMap tiles; the marker always represents the saved coordinates.
class IncidentLocationMap extends StatefulWidget {
  const IncidentLocationMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.tileProvider,
    this.onLocationChanged,
  });
  final double latitude;
  final double longitude;
  final double? accuracy;
  final TileProvider? tileProvider;
  final void Function(double latitude, double longitude)? onLocationChanged;
  @override
  State<IncidentLocationMap> createState() => _IncidentLocationMapState();
}

class _IncidentLocationMapState extends State<IncidentLocationMap> {
  final _controller = MapController();
  bool _ready = false;
  bool _tileError = false;
  late LatLng _point;

  @override
  void initState() {
    super.initState();
    _point = LatLng(widget.latitude, widget.longitude);
  }

  @override
  void didUpdateWidget(covariant IncidentLocationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      _point = LatLng(widget.latitude, widget.longitude);
      if (_ready) _controller.move(_point, 16);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: 250,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              FlutterMap(
                mapController: _controller,
                options: MapOptions(
                  initialCenter: _point,
                  initialZoom: 16,
                  minZoom: 3,
                  maxZoom: 19,
                  onMapReady: () => _ready = true,
                  onTap: (_, latlng) {
                    setState(() {
                      _point = latlng;
                    });
                    widget.onLocationChanged?.call(
                      latlng.latitude,
                      latlng.longitude,
                    );
                  },
                  onPositionChanged: (position, hasGesture) {
                    if (!hasGesture) return;
                    final center = position.center;
                    final next = LatLng(center.latitude, center.longitude);
                    if (next != _point) {
                      setState(() => _point = next);
                      widget.onLocationChanged?.call(
                        next.latitude,
                        next.longitude,
                      );
                    }
                  },
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.wildora.wildora',
                    tileProvider: widget.tileProvider,
                    // Use flutter_map's default cache; never prefetch offline tile areas.
                    errorTileCallback: (_, error, stack) {
                      if (!_tileError && mounted) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() => _tileError = true);
                        });
                      }
                    },
                  ),
                  if (widget.accuracy != null &&
                      widget.accuracy!.isFinite &&
                      widget.accuracy! > 0)
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: _point,
                          radius: widget.accuracy!,
                          useRadiusInMeter: true,
                          color: Colors.blue.withValues(alpha: 0.12),
                          borderColor: Colors.blue.withValues(alpha: 0.5),
                          borderStrokeWidth: 1,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _point,
                        width: 46,
                        height: 46,
                        alignment: Alignment.bottomCenter,
                        child: const Icon(
                          Icons.location_on,
                          color: incidentGreen,
                          size: 46,
                          semanticLabel: 'Incident location',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Center on incident location',
                    onPressed: () => _controller.move(_point, 16),
                    icon: const Icon(Icons.my_location, color: incidentGreen),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Material(
                  color: Colors.white.withValues(alpha: 0.95),
                  child: InkWell(
                    onTap: () async {
                      final opened = await launchUrl(
                        Uri.parse('https://www.openstreetmap.org/copyright'),
                      );
                      if (!opened && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'OpenStreetMap contributors: openstreetmap.org/copyright',
                            ),
                          ),
                        );
                      }
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Text(
                        '© OpenStreetMap contributors',
                        style: TextStyle(color: incidentGreen, fontSize: 11),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      if (_tileError)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Map tiles are unavailable. Your coordinates are still captured and can be saved.',
          ),
        ),
    ],
  );
}
