import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../application/patrol_controller.dart';
import '../data/patrol_models.dart';
import 'add_waypoint_screen.dart';
import 'patrol_completed_screen.dart';
import 'patrol_map_view.dart';
import 'patrol_theme.dart';
import 'patrol_widgets.dart';

/// Screen 2: Patrol In Progress
///
/// Tactical operational interface featuring live OpenStreetMap path tracking,
/// elapsed duration and recorded GPS distance telemetry, manual and automatic
/// GPS fix capture, waypoint logging, deviation recording, and confirmed completion.
class PatrolInProgressScreen extends StatefulWidget {
  const PatrolInProgressScreen({super.key, required this.controller});

  final PatrolController controller;

  @override
  State<PatrolInProgressScreen> createState() => _PatrolInProgressScreenState();
}

class _PatrolInProgressScreenState extends State<PatrolInProgressScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.controller.startGpsTracking();
      }
    });
  }

  Future<void> _addWaypoint() async {
    if (widget.controller.currentSession?.lifecycleStatus !=
        PatrolLifecycleStatus.active) {
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddWaypointScreen(controller: widget.controller),
      ),
    );
  }

  Future<void> _recordDeviation() async {
    if (widget.controller.currentSession?.lifecycleStatus !=
        PatrolLifecycleStatus.active) {
      return;
    }

    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PatrolTheme.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: PatrolTheme.radiusMd),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: PatrolTheme.amberSurface,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.alt_route,
                  color: PatrolTheme.amberDark, size: 20),
            ),
            SizedBox(width: 10),
            Text(
              'Log Route Deviation',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: PatrolTheme.charcoal,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Record an operational departure from the assigned route trajectory without altering the original plan.',
              style: TextStyle(fontSize: 13, color: PatrolTheme.charcoalMuted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Operational Reason (Optional)',
                hintText: 'e.g. Washout flooding, elephant herd crossing',
                labelStyle: const TextStyle(fontSize: 13),
                filled: true,
                fillColor: PatrolTheme.surfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: PatrolTheme.radiusSm,
                  borderSide: const BorderSide(color: PatrolTheme.borderLight),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Confirm Deviation'),
            style: FilledButton.styleFrom(
              backgroundColor: PatrolTheme.amberDark,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final session = widget.controller.currentSession;
    double lat;
    double lng;
    final lastTrack = session!.trackPoints.isNotEmpty
        ? session.trackPoints.last
        : null;

    if (lastTrack != null) {
      lat = lastTrack.latitude;
      lng = lastTrack.longitude;
    } else {
      try {
        final point =
            await widget.controller.locationService.captureCurrentPosition();
        lat = point.latitude;
        lng = point.longitude;
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('GPS fix unavailable. Deviation could not be mapped.'),
              backgroundColor: PatrolTheme.amberDark,
            ),
          );
        }
        return;
      }
    }

    await widget.controller.recordDeviation(
      latitude: lat,
      longitude: lng,
      reason: reasonController.text.trim().isEmpty
          ? null
          : reasonController.text.trim(),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Route deviation recorded with spatial coordinates.'),
          backgroundColor: PatrolTheme.forestPrimary,
        ),
      );
    }
  }

  Future<void> _completePatrol() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PatrolTheme.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: PatrolTheme.radiusMd),
        title: const Text(
          'Complete Patrol?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: PatrolTheme.charcoal,
          ),
        ),
        content: const Text(
          'Are you sure you want to complete this patrol? '
          'GPS tracking will stop and your debrief summary will be saved to local storage.',
          style: TextStyle(color: PatrolTheme.charcoalMuted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: PatrolTheme.amberDark,
              foregroundColor: Colors.white,
            ),
            child: const Text('Complete Patrol'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final success = await widget.controller.completePatrol();
    if (success && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PatrolCompletedScreen(controller: widget.controller),
        ),
      );
    } else if (mounted && widget.controller.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.controller.error!),
          backgroundColor: PatrolTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final session = widget.controller.currentSession;
        if (session == null) {
          return const Scaffold(
            body: Center(child: Text('No active patrol session.')),
          );
        }

        return Scaffold(
          backgroundColor: PatrolTheme.background,
          appBar: AppBar(
            title: const Text('Patrol In Progress'),
            backgroundColor: PatrolTheme.forestDeep,
            foregroundColor: Colors.white,
            elevation: 0,
            automaticallyImplyLeading: false,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: GpsStatusBadge(
                  available: widget.controller.gpsAvailable,
                  lastFix: widget.controller.lastGpsFix,
                  status: widget.controller.gpsSignalStatus,
                  accuracy: widget.controller.gpsAccuracy,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ConnectivityBadge(
                  isOnline: widget.controller.isOnline,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SyncStatusIcon(
                  status: session.syncMetadata.syncStatus,
                  compact: true,
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              // ─── Active Operational Status Strip ─────────────────────────
              Container(
                width: double.infinity,
                color: PatrolTheme.forestPrimary,
                padding:
                    const EdgeInsets.symmetric(vertical: 7, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4ADE80),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'ACTIVE FIELD PATROL',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '• ${session.routeName}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),


              // ─── Main Content Area ───────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  child: ResponsiveContentWrapper(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Interactive OpenStreetMap Track Card
                        _buildMapCard(session),

                        const SizedBox(height: 14),

                        // Real-time telemetry metrics
                        _buildTelemetryRow(session),

                        const SizedBox(height: 12),

                        // Secondary metrics row (GPS points & waypoints)
                        _buildSecondaryMetrics(session),

                        const SizedBox(height: 14),

                        // GPS Unavailable warning banner if signal is dropped/denied
                        if (!widget.controller.gpsAvailable ||
                            widget.controller.gpsSignalStatus !=
                                GpsSignalStatus.available)
                          _buildGpsWarningBanner(),

                        const SizedBox(height: 16),

                        // Tactical Field Action Buttons
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: SizedBox(
                                height: 52,
                                child: FilledButton.icon(
                                  onPressed: _addWaypoint,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: PatrolTheme.forestPrimary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: PatrolTheme.radiusMd,
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  icon: const Icon(Icons.add_location_alt,
                                      size: 20),
                                  label: const Text('Add Waypoint'),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: SizedBox(
                                height: 52,
                                child: OutlinedButton.icon(
                                  onPressed: _recordDeviation,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: PatrolTheme.charcoal,
                                    side: const BorderSide(
                                        color: PatrolTheme.borderLight,
                                        width: 1.5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: PatrolTheme.radiusMd,
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  icon: const Icon(Icons.alt_route,
                                      size: 18, color: PatrolTheme.amberDark),
                                  label: const Text('Deviation'),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Manual GPS Fix Trigger Button
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 44,
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      widget.controller.captureGpsFix(),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: PatrolTheme.forestPrimary,
                                    side: const BorderSide(
                                      color: PatrolTheme.forestBorder,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: PatrolTheme.radiusSm,
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  icon: const Icon(Icons.my_location, size: 16),
                                  label: const Text('Record GPS Fix'),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Logged Waypoints List during active patrol
                        if (session.waypoints.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Container(
                            decoration: PatrolTheme.cardDecoration(),
                            clipBehavior: Clip.antiAlias,
                            child: Theme(
                              data: Theme.of(context)
                                  .copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                tilePadding:
                                    const EdgeInsets.symmetric(horizontal: 14),
                                leading: const Icon(Icons.place_outlined,
                                    size: 20, color: PatrolTheme.forestPrimary),
                                title: Text(
                                  'Logged Waypoints (${session.waypoints.length})',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: PatrolTheme.charcoal,
                                  ),
                                ),
                                subtitle: const Text(
                                  'Tap any waypoint to view details & sync state',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: PatrolTheme.charcoalMuted,
                                  ),
                                ),
                                children: [
                                  WaypointListPanel(
                                    waypoints: session.waypoints,
                                    isRanger: true,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // Complete Patrol (Isolated with Distinct Amber Action)
                        SizedBox(
                          height: 54,
                          child: FilledButton.icon(
                            onPressed: widget.controller.isLoading
                                ? null
                                : _completePatrol,
                            style: FilledButton.styleFrom(
                              backgroundColor: PatrolTheme.amberDark,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: PatrolTheme.radiusMd,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                            icon: const Icon(Icons.check_circle_outline,
                                size: 22),
                            label: widget.controller.isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Complete Patrol'),
                          ),
                        ),

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMapCard(PatrolSession session) {
    LatLng? currentFix;
    if (session.trackPoints.isNotEmpty) {
      final last = session.trackPoints.last;
      currentFix = LatLng(last.latitude, last.longitude);
    }

    return Container(
      decoration: PatrolTheme.cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Tactical Header Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: PatrolTheme.surfaceElevated,
            child: Row(
              children: [
                const Icon(Icons.layers_outlined,
                    size: 16, color: PatrolTheme.forestPrimary),
                const SizedBox(width: 6),
                const Text(
                  'Live Tactical Map & GPS Track',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: PatrolTheme.charcoal,
                  ),
                ),
                const Spacer(),
                // Visual Legend
                _buildLegendPill(const Color(0xFF2563EB), 'Planned'),
                const SizedBox(width: 6),
                _buildLegendPill(PatrolTheme.forestPrimary, 'Track'),
                const SizedBox(width: 6),
                _buildLegendPill(PatrolTheme.amberDark, 'Waypoint'),
              ],
            ),
          ),

          // Real OpenStreetMap Canvas
          PatrolMapView(
            trackPoints: session.trackPoints,
            checkpoints: session.checkpoints,
            waypoints: session.waypoints,
            deviations: session.deviations,
            currentPosition: currentFix,
            accuracy: widget.controller.gpsAccuracy,
            height: 250,
            interactive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildLegendPill(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: PatrolTheme.charcoalMuted),
        ),
      ],
    );
  }

  Widget _buildTelemetryRow(PatrolSession session) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            icon: Icons.timer,
            label: 'Elapsed Duration',
            value: _formatDuration(session.actualDuration),
            accentColor: PatrolTheme.forestPrimary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            icon: Icons.straighten,
            label: 'Recorded Distance',
            value: '${session.recordedDistanceKm.toStringAsFixed(2)} km',
            accentColor: PatrolTheme.forestMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildSecondaryMetrics(PatrolSession session) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            icon: Icons.gps_fixed,
            label: 'GPS Track Points',
            value: '${session.trackPoints.length}',
            accentColor: PatrolTheme.infoBlue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            icon: Icons.flag,
            label: 'Logged Waypoints',
            value: '${session.waypoints.length}',
            accentColor: PatrolTheme.amberDark,
          ),
        ),
      ],
    );
  }

  Widget _buildGpsWarningBanner() {
    final status = widget.controller.gpsSignalStatus;
    String title = 'GPS Signal Disrupted';
    String message =
        'Spatial tracking is temporarily paused. Manual coordinate input remains functional.';

    if (status == GpsSignalStatus.denied ||
        status == GpsSignalStatus.permanentlyDenied) {
      title = 'Location Permission Denied';
      message =
          'Allow location permissions in browser site settings or phone settings to track live movements.';
    } else if (status == GpsSignalStatus.servicesDisabled) {
      title = 'Device Location Turned Off';
      message = 'Please turn on Location / GPS in your device settings.';
    } else if (status == GpsSignalStatus.stale) {
      title = 'Stale GPS Position';
      message =
          'No recent satellite updates. Moving outdoors helps acquire faster fixes.';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PatrolTheme.amberSurface,
        borderRadius: PatrolTheme.radiusMd,
        border: Border.all(color: PatrolTheme.amberBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.gps_off, color: PatrolTheme.amberDark, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: PatrolTheme.amberDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(
                      fontSize: 11, color: PatrolTheme.charcoal),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => widget.controller.captureGpsFix(),
            icon: const Icon(Icons.refresh, color: PatrolTheme.amberDark),
            tooltip: 'Retry GPS Fix',
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}

/// Stat metric card for telemetry readouts.
class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accentColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: PatrolTheme.cardDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accentColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: PatrolTheme.charcoalMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: PatrolTheme.charcoal,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
