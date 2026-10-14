import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

/// An actual OSM map. The initial Sri Lanka viewport is never a selected location.
class IncidentLocationMap extends StatefulWidget {
  const IncidentLocationMap({
    super.key,
    this.latitude,
    this.longitude,
    this.onSelect,
    this.tileProvider,
  });

  final double? latitude;
  final double? longitude;
  final ValueChanged<LatLng>? onSelect;
  final TileProvider? tileProvider;

  @override
  State<IncidentLocationMap> createState() => _IncidentLocationMapState();
}

class _IncidentLocationMapState extends State<IncidentLocationMap> {
  final _controller = MapController();
  bool _ready = false;
  bool _tilesUnavailable = false;
  int _tileGeneration = 0;

  LatLng? get _selected => widget.latitude == null || widget.longitude == null
      ? null
      : LatLng(widget.latitude!, widget.longitude!);

  @override
  void didUpdateWidget(covariant IncidentLocationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_ready &&
        _selected != null &&
        (oldWidget.latitude != widget.latitude ||
            oldWidget.longitude != widget.longitude)) {
      _controller.move(_selected!, 15);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _tileError() {
    if (_tilesUnavailable) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_tilesUnavailable) {
        setState(() => _tilesUnavailable = true);
      }
    });
  }

  Future<void> _showAttribution() async {
    try {
      if (await launchUrl(
        Uri.parse('https://www.openstreetmap.org/copyright'),
      )) {
        return;
      }
    } on Object {
      // The visible credit remains available even without a browser.
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OpenStreetMap: openstreetmap.org/copyright'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 240,
    child: Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: _selected ?? const LatLng(7.8731, 80.7718),
            initialZoom: _selected == null ? 7 : 15,
            minZoom: 3,
            maxZoom: 19,
            onMapReady: () => _ready = true,
            interactionOptions: InteractionOptions(
              flags: widget.onSelect == null
                  ? InteractiveFlag.none
                  : InteractiveFlag.drag |
                        InteractiveFlag.pinchZoom |
                        InteractiveFlag.doubleTapZoom |
                        InteractiveFlag.scrollWheelZoom,
            ),
            onTap: widget.onSelect == null
                ? null
                : (_, point) {
                    if (point.latitude.abs() <= 90) {
                      widget.onSelect!(
                        LatLng(
                          point.latitude,
                          ((point.longitude + 180) % 360) - 180,
                        ),
                      );
                    }
                  },
          ),
          children: [
            TileLayer(
              key: ValueKey(_tileGeneration),
              urlTemplate: const String.fromEnvironment(
                'CONFLICT_MAP_TILE_URL',
                defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              ),
              userAgentPackageName: 'com.wildora.wildora',
              tileProvider: widget.tileProvider,
              maxNativeZoom: 19,
              panBuffer: 0,
              errorTileCallback: (_, _, _) => _tileError(),
            ),
            if (_selected != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selected!,
                    width: 44,
                    height: 44,
                    alignment: Alignment.topCenter,
                    child: Semantics(
                      label: 'Selected incident location',
                      child: Icon(
                        Icons.location_pin,
                        size: 44,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
        if (_tilesUnavailable)
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Map unavailable. Check your connection; you can still use GPS or enter coordinates.',
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _tilesUnavailable = false;
                        _tileGeneration++;
                      }),
                      child: const Text('Retry map'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            child: InkWell(
              onTap: _showAttribution,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Text(
                  '© OpenStreetMap contributors',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
