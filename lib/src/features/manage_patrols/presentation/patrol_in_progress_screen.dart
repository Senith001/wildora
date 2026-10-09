import 'package:flutter/material.dart';

import '../application/patrol_controller.dart';
import '../data/patrol_models.dart';
import 'add_waypoint_screen.dart';
import 'patrol_completed_screen.dart';
import 'patrol_widgets.dart';

/// Screen 2: Patrol In Progress
///
/// Active patrol monitoring with GPS tracking, map visualization,
/// elapsed duration, distance, waypoint/deviation actions, and
/// completion flow.
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
    // Start GPS tracking when entering this screen
    widget.controller.startGpsTracking();
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
    final session = widget.controller.currentSession;
    if (session?.lifecycleStatus != PatrolLifecycleStatus.active) return;

    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Route Deviation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Record that you are deviating from the assigned route. '
              'Your current GPS position will be used if available.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'e.g. Trail blocked by fallen tree',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Record'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Try to get current position for the deviation
    double lat = 0;
    double lng = 0;
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
              content: Text(
                  'GPS unavailable. Deviation recorded without coordinates.'),
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
          content: Text('Route deviation recorded.'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    }
  }

  Future<void> _completePatrol() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete Patrol?'),
        content: const Text(
          'Are you sure you want to complete this patrol? '
          'GPS tracking will stop and no more waypoints can be added.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
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
          backgroundColor: Colors.red.shade700,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _completePatrol,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

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
          appBar: AppBar(
            title: const Text('Patrol In Progress'),
            automaticallyImplyLeading: false,
            actions: [
              // GPS indicator
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: GpsStatusBadge(
                  available: widget.controller.gpsAvailable,
                  lastFix: widget.controller.lastGpsFix,
                ),
              ),
              // Connectivity indicator
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: ConnectivityBadge(
                  isOnline: widget.controller.isOnline,
                ),
              ),
              // Sync status
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SyncStatusIcon(
                  status: session.syncMetadata.syncStatus,
                  compact: true,
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              // Status badge
              Container(
                width: double.infinity,
                color: const Color(0xFF2E7D32),
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: const Center(
                  child: Text(
                    '● ACTIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Map / Track visualization
                      _buildMapCard(session, theme, colors),

                      const SizedBox(height: 16),

                      // Stats row
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              icon: Icons.timer,
                              label: 'Elapsed',
                              value: _formatDuration(session.actualDuration),
                              color: colors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.straighten,
                              label: 'Distance',
                              value:
                                  '${session.recordedDistanceKm.toStringAsFixed(2)} km',
                              color: colors.tertiary,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              icon: Icons.location_on,
                              label: 'GPS Points',
                              value: '${session.trackPoints.length}',
                              color: colors.secondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.flag,
                              label: 'Waypoints',
                              value: '${session.waypoints.length}',
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // GPS unavailable warning
                      if (!widget.controller.gpsAvailable)
                        Card(
                          color: Colors.orange.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Icon(Icons.gps_off,
                                    color: Colors.orange.shade700),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'GPS Unavailable',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange.shade900,
                                        ),
                                      ),
                                      Text(
                                        'Automatic tracking is paused. '
                                        'You can still add waypoints manually.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.orange.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      widget.controller.captureGpsFix(),
                                  icon: const Icon(Icons.refresh),
                                  tooltip: 'Retry GPS',
                                ),
                              ],
                            ),
                          ),
                        ),

                      const SizedBox(height: 16),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 52,
                              child: OutlinedButton.icon(
                                onPressed: _addWaypoint,
                                icon: const Icon(Icons.add_location_alt),
                                label: const Text('Add Waypoint'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 52,
                              child: OutlinedButton.icon(
                                onPressed: _recordDeviation,
                                icon: const Icon(Icons.alt_route),
                                label: const Text('Deviation'),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Complete Patrol button
                      SizedBox(
                        height: 56,
                        child: FilledButton.icon(
                          onPressed:
                              widget.controller.isLoading ? null : _completePatrol,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.orange.shade700,
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          icon: const Icon(Icons.check_circle),
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
            ],
          ),
        );
      },
    );
  }

  Widget _buildMapCard(
    PatrolSession session,
    ThemeData theme,
    ColorScheme colors,
  ) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.primaryContainer.withValues(alpha: 0.2),
              colors.surfaceContainerLow,
            ],
          ),
        ),
        child: Stack(
          children: [
            // Simple track visualization
            if (session.trackPoints.isNotEmpty)
              CustomPaint(
                size: const Size(double.infinity, 200),
                painter: _TrackPainter(
                  trackPoints: session.trackPoints,
                  waypoints: session.waypoints,
                  primaryColor: colors.primary,
                  waypointColor: Colors.orange.shade700,
                ),
              )
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.gps_fixed,
                        size: 40,
                        color: colors.primary.withValues(alpha: 0.4)),
                    const SizedBox(height: 8),
                    Text(
                      'Waiting for GPS fixes…',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            // Route label
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 3,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text('Track', style: theme.textTheme.labelSmall),
                    const SizedBox(width: 12),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.orange.shade700,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text('Waypoint', style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
            ),
          ],
        ),
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

// ─── Simple track painter ───────────────────────────────────────────

class _TrackPainter extends CustomPainter {
  _TrackPainter({
    required this.trackPoints,
    required this.waypoints,
    required this.primaryColor,
    required this.waypointColor,
  });

  final List<TrackPoint> trackPoints;
  final List<Waypoint> waypoints;
  final Color primaryColor;
  final Color waypointColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (trackPoints.isEmpty) return;

    // Calculate bounds
    double minLat = trackPoints.first.latitude;
    double maxLat = trackPoints.first.latitude;
    double minLng = trackPoints.first.longitude;
    double maxLng = trackPoints.first.longitude;

    for (final p in trackPoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    for (final w in waypoints) {
      if (w.latitude < minLat) minLat = w.latitude;
      if (w.latitude > maxLat) maxLat = w.latitude;
      if (w.longitude < minLng) minLng = w.longitude;
      if (w.longitude > maxLng) maxLng = w.longitude;
    }

    final latRange = (maxLat - minLat).clamp(0.0001, double.infinity);
    final lngRange = (maxLng - minLng).clamp(0.0001, double.infinity);
    const padding = 24.0;
    final drawWidth = size.width - padding * 2;
    final drawHeight = size.height - padding * 2;

    Offset toCanvas(double lat, double lng) {
      final x = padding + ((lng - minLng) / lngRange) * drawWidth;
      final y = padding + ((maxLat - lat) / latRange) * drawHeight;
      return Offset(x, y);
    }

    // Draw track line
    final trackPaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final first = toCanvas(trackPoints.first.latitude, trackPoints.first.longitude);
    path.moveTo(first.dx, first.dy);
    for (int i = 1; i < trackPoints.length; i++) {
      final p = toCanvas(trackPoints[i].latitude, trackPoints[i].longitude);
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, trackPaint);

    // Draw track points
    final pointPaint = Paint()..color = primaryColor;
    for (final p in trackPoints) {
      canvas.drawCircle(toCanvas(p.latitude, p.longitude), 3, pointPaint);
    }

    // Draw waypoints
    final wpPaint = Paint()..color = waypointColor;
    for (final w in waypoints) {
      canvas.drawCircle(toCanvas(w.latitude, w.longitude), 6, wpPaint);
      canvas.drawCircle(
        toCanvas(w.latitude, w.longitude),
        6,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_TrackPainter old) =>
      trackPoints.length != old.trackPoints.length ||
      waypoints.length != old.waypoints.length;
}

// ─── Stat Card ──────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
