import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/patrol_models.dart';
import 'patrol_theme.dart';
import 'patrol_widgets.dart';

/// Full interactive field map view using [FlutterMap] and OpenStreetMap.
///
/// Provides:
/// - Distinct rendering for assigned route checkpoints vs live recorded track.
/// - Current position marker with accuracy halo and last-fix time.
/// - Waypoint markers with visual category icons and inspection popups.
/// - Smooth automatic initial fix centering without fighting user panning.
/// - Floating "Recenter" and "Fit Route" tactical controls.
/// - Graceful offline tile error handling without blocking patrol tracking.
class PatrolMapView extends StatefulWidget {
  const PatrolMapView({
    super.key,
    required this.trackPoints,
    this.checkpoints = const [],
    this.waypoints = const [],
    this.deviations = const [],
    this.currentPosition,
    this.accuracy,
    this.height = 280,
    this.interactive = true,
    this.isRanger = true,
    this.onTapCoordinate,
  });

  final List<TrackPoint> trackPoints;
  final List<PatrolCheckpoint> checkpoints;
  final List<Waypoint> waypoints;
  final List<RouteDeviation> deviations;
  final LatLng? currentPosition;
  final double? accuracy;
  final double height;
  final bool interactive;
  final bool isRanger;
  final void Function(LatLng point)? onTapCoordinate;

  @override
  State<PatrolMapView> createState() => _PatrolMapViewState();
}

class _PatrolMapViewState extends State<PatrolMapView> {
  final MapController _mapController = MapController();
  bool _isReady = false;
  bool _tileError = false;
  bool _userHasPanned = false;
  bool _hasInitialCentered = false;

  // Default coordinate (Yala National Park, Sri Lanka)
  static const LatLng _defaultCenter = LatLng(6.3685, 81.5175);

  @override
  void didUpdateWidget(covariant PatrolMapView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Initial centering when first fix arrives
    if (!_hasInitialCentered && widget.currentPosition != null && _isReady) {
      _hasInitialCentered = true;
      _mapController.move(widget.currentPosition!, 15.0);
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _recenterOnUser() {
    setState(() => _userHasPanned = false);
    if (widget.currentPosition != null) {
      _mapController.move(widget.currentPosition!, 16.0);
    } else if (widget.trackPoints.isNotEmpty) {
      final last = widget.trackPoints.last;
      _mapController.move(LatLng(last.latitude, last.longitude), 16.0);
    } else if (widget.checkpoints.isNotEmpty) {
      final first = widget.checkpoints.first;
      _mapController.move(LatLng(first.latitude, first.longitude), 14.0);
    } else {
      _mapController.move(_defaultCenter, 14.0);
    }
  }

  void _fitRouteBounds() {
    setState(() => _userHasPanned = false);
    final allPoints = <LatLng>[];

    for (final cp in widget.checkpoints) {
      allPoints.add(LatLng(cp.latitude, cp.longitude));
    }
    for (final tp in widget.trackPoints) {
      allPoints.add(LatLng(tp.latitude, tp.longitude));
    }
    if (widget.currentPosition != null) {
      allPoints.add(widget.currentPosition!);
    }

    if (allPoints.isEmpty) {
      _mapController.move(_defaultCenter, 14.0);
      return;
    }

    final bounds = LatLngBounds.fromPoints(allPoints);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(36),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initialCenter = widget.currentPosition ??
        (widget.trackPoints.isNotEmpty
            ? LatLng(widget.trackPoints.last.latitude,
                widget.trackPoints.last.longitude)
            : widget.checkpoints.isNotEmpty
                ? LatLng(widget.checkpoints.first.latitude,
                    widget.checkpoints.first.longitude)
                : _defaultCenter);

    return Container(
      height: widget.height,
      decoration: PatrolTheme.cardDecoration(
        backgroundColor: const Color(0xFFF3F7F2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: 14.5,
              minZoom: 3,
              maxZoom: 19,
              onMapReady: () {
                _isReady = true;
                if (widget.currentPosition != null) {
                  _hasInitialCentered = true;
                  _mapController.move(widget.currentPosition!, 15.0);
                }
              },
              onTap: (_, point) {
                widget.onTapCoordinate?.call(point);
              },
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) {
                  _userHasPanned = true;
                }
              },
              interactionOptions: InteractionOptions(
                flags: widget.interactive
                    ? InteractiveFlag.all & ~InteractiveFlag.rotate
                    : InteractiveFlag.none,
              ),
            ),
            children: [
              // 1. OpenStreetMap Tile Layer
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.wildora.wildora',
                errorTileCallback: (tile, error, stackTrace) {
                  if (!_tileError && mounted) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _tileError = true);
                    });
                  }
                },
              ),

              // 2. Assigned Route Polylines (Planned Path)
              if (widget.checkpoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: widget.checkpoints
                          .map((c) => LatLng(c.latitude, c.longitude))
                          .toList(),
                      color: const Color(0xFF2563EB).withValues(alpha: 0.8),
                      strokeWidth: 3.5,
                      strokeCap: StrokeCap.round,
                    ),
                  ],
                ),

              // 3. Live Recorded GPS Track Polylines
              if (widget.trackPoints.length >= 2)
                PolylineLayer(
                  polylines: _buildContinuousGpsPolylines(),
                ),

              // 4. GPS Accuracy Circle
              if (widget.currentPosition != null &&
                  widget.accuracy != null &&
                  widget.accuracy!.isFinite &&
                  widget.accuracy! > 0)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: widget.currentPosition!,
                      radius: widget.accuracy!.clamp(5.0, 50.0),
                      useRadiusInMeter: true,
                      color: PatrolTheme.forestPrimary.withValues(alpha: 0.12),
                      borderColor:
                          PatrolTheme.forestPrimary.withValues(alpha: 0.4),
                      borderStrokeWidth: 1.2,
                    ),
                  ],
                ),

              // 5. Checkpoints, Waypoints, Deviations, and Current Position Markers
              MarkerLayer(
                markers: [
                  // Assigned Checkpoint Markers
                  ...widget.checkpoints.map((cp) => Marker(
                        point: LatLng(cp.latitude, cp.longitude),
                        width: 28,
                        height: 28,
                        child: _buildCheckpointMarker(cp),
                      )),

                  // Field Waypoint Markers
                  ...widget.waypoints.map((wp) => Marker(
                        point: LatLng(wp.latitude, wp.longitude),
                        width: 32,
                        height: 32,
                        child: _buildWaypointMarker(wp),
                      )),

                  // Deviation Markers
                  ...widget.deviations.map((d) => Marker(
                        point: LatLng(d.latitude, d.longitude),
                        width: 26,
                        height: 26,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: PatrolTheme.amberDark,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.alt_route,
                              color: Colors.white, size: 14),
                        ),
                      )),

                  // Current Position Marker
                  if (widget.currentPosition != null)
                    Marker(
                      point: widget.currentPosition!,
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      child: _buildCurrentPositionMarker(),
                    )
                  else if (widget.trackPoints.isNotEmpty)
                    Marker(
                      point: LatLng(
                        widget.trackPoints.last.latitude,
                        widget.trackPoints.last.longitude,
                      ),
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      child: _buildCurrentPositionMarker(),
                    ),
                ],
              ),
            ],
          ),

          // ─── Floating Tactical Controls ──────────────────────────────
          if (widget.interactive)
            Positioned(
              right: 12,
              top: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Recenter on Current Fix
                  _buildMapActionButton(
                    icon: Icons.my_location,
                    tooltip: 'Recenter on My Position',
                    color: _userHasPanned
                        ? PatrolTheme.forestPrimary
                        : PatrolTheme.forestDeep,
                    onPressed: _recenterOnUser,
                  ),
                  const SizedBox(height: 8),

                  // Fit Route Extents
                  _buildMapActionButton(
                    icon: Icons.fit_screen_outlined,
                    tooltip: 'Fit Entire Route to Screen',
                    color: PatrolTheme.charcoal,
                    onPressed: _fitRouteBounds,
                  ),
                ],
              ),
            ),

          // ─── Offline Tile Notification Pill (Non-blocking) ────────────
          if (_tileError)
            Positioned(
              left: 12,
              bottom: 24,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: PatrolTheme.radiusFull,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi_off, size: 12, color: Colors.amber),
                    SizedBox(width: 6),
                    Text(
                      'Tiles offline • Spatial GPS tracking operational',
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),

          // ─── OpenStreetMap Attribution ──────────────────────────────
          Positioned(
            right: 4,
            bottom: 4,
            child: Material(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(4),
              child: InkWell(
                onTap: () => launchUrl(
                  Uri.parse('https://www.openstreetmap.org/copyright'),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  child: Text(
                    '© OpenStreetMap',
                    style: TextStyle(
                      fontSize: 9,
                      color: PatrolTheme.forestDeep,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapActionButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(icon, size: 18, color: color),
        tooltip: tooltip,
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
        padding: const EdgeInsets.all(8),
      ),
    );
  }

  Widget _buildCheckpointMarker(PatrolCheckpoint cp) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Center(
        child: Text(
          '${cp.order}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildWaypointMarker(Waypoint wp) {
    return GestureDetector(
      onTap: () => _showWaypointInfo(wp),
      child: Container(
        decoration: BoxDecoration(
          color: PatrolTheme.amberDark,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(
                color: Colors.black26, blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
        child: Center(
          child: Icon(_waypointIcon(wp.type), size: 16, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildCurrentPositionMarker() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: PatrolTheme.forestPrimary.withValues(alpha: 0.25),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: PatrolTheme.forestPrimary,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black38, blurRadius: 4, offset: Offset(0, 1)),
            ],
          ),
        ),
      ],
    );
  }

  /// Groups consecutive GPS track points into polylines, breaking across gaps (>=5 min).
  List<Polyline> _buildContinuousGpsPolylines() {
    final polylines = <Polyline>[];
    if (widget.trackPoints.length < 2) return polylines;

    var currentSegment = <LatLng>[
      LatLng(widget.trackPoints.first.latitude,
          widget.trackPoints.first.longitude),
    ];

    for (int i = 1; i < widget.trackPoints.length; i++) {
      final prev = widget.trackPoints[i - 1];
      final curr = widget.trackPoints[i];
      final gap = curr.timestamp.difference(prev.timestamp);

      if (gap.inMinutes >= 5) {
        // Gap detected: save current line segment, start fresh
        if (currentSegment.length >= 2) {
          polylines.add(Polyline(
            points: List.from(currentSegment),
            color: PatrolTheme.forestPrimary,
            strokeWidth: 4.0,
            strokeCap: StrokeCap.round,
          ));
        }
        currentSegment = [LatLng(curr.latitude, curr.longitude)];
      } else {
        currentSegment.add(LatLng(curr.latitude, curr.longitude));
      }
    }

    if (currentSegment.length >= 2) {
      polylines.add(Polyline(
        points: currentSegment,
        color: PatrolTheme.forestPrimary,
        strokeWidth: 4.0,
        strokeCap: StrokeCap.round,
      ));
    }

    return polylines;
  }

  IconData _waypointIcon(WaypointType type) {
    switch (type) {
      case WaypointType.animalSighting:
        return Icons.pets;
      case WaypointType.evidence:
        return Icons.search;
      case WaypointType.trailMarker:
        return Icons.flag;
      case WaypointType.waterSource:
        return Icons.water_drop;
      case WaypointType.other:
        return Icons.location_on;
    }
  }

  void _showWaypointInfo(Waypoint wp) {
    showWaypointDetail(context, wp, isRanger: widget.isRanger);
  }
}
