import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../application/patrol_controller.dart';
import '../data/patrol_models.dart';
import 'patrol_map_view.dart';
import 'patrol_theme.dart';
import 'patrol_widgets.dart';

/// Screen for Park Managers and Chief Wardens to review completed and synchronized
/// ranger patrols, spatial coverage, logged field waypoints, and monitor live active units.
class ManagerPatrolReviewScreen extends StatefulWidget {
  const ManagerPatrolReviewScreen({super.key, required this.controller});

  final PatrolController controller;

  @override
  State<ManagerPatrolReviewScreen> createState() =>
      _ManagerPatrolReviewScreenState();
}

class _ManagerPatrolReviewScreenState extends State<ManagerPatrolReviewScreen> {
  List<PatrolSession> _sessions = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final sessions =
          await widget.controller.syncService.getSynchronizedPatrolSessions();
      if (mounted) {
        setState(() {
          _sessions = sessions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load patrol sessions: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: PatrolTheme.background,
        appBar: AppBar(
          title: const Text('Manager Patrol Review'),
          backgroundColor: PatrolTheme.forestDeep,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh from Cloud Firestore',
              onPressed: _loadSessions,
            ),
          ],
          bottom: const TabBar(
            indicatorColor: PatrolTheme.amber,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(
                icon: Icon(Icons.assignment_turned_in, size: 18),
                text: 'Completed Debriefs',
              ),
              Tab(
                icon: Icon(Icons.sensors, size: 18),
                text: 'Live Field Units',
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              // ─── TAB 1: Completed Debriefs ───────────────────────────────
              _buildCompletedTab(),

              // ─── TAB 2: Live Field Units ─────────────────────────────────
              _buildLiveUnitsTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletedTab() {
    final totalDistance =
        _sessions.fold<double>(0.0, (acc, s) => acc + s.recordedDistanceKm);
    final totalWaypoints =
        _sessions.fold<int>(0, (acc, s) => acc + s.waypoints.length);

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: PatrolTheme.forestPrimary),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSessions,
      color: PatrolTheme.forestPrimary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: ResponsiveContentWrapper(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Manager Authority Banner
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: PatrolTheme.forestSurface,
                  borderRadius: PatrolTheme.radiusMd,
                  border: Border.all(color: PatrolTheme.forestBorder),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield,
                        color: PatrolTheme.forestPrimary, size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Field Operations Debrief Console',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: PatrolTheme.forestDeep,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Review verified server-delivered coverage, GPS tracks, and observation waypoints.',
                            style: TextStyle(
                              fontSize: 11,
                              color: PatrolTheme.charcoalMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // High-Level Conservation Metrics Grid
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Completed Patrols',
                      value: '${_sessions.length}',
                      icon: Icons.assignment_turned_in,
                      color: PatrolTheme.forestPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Distance Covered',
                      value: '${totalDistance.toStringAsFixed(1)} km',
                      icon: Icons.straighten,
                      color: PatrolTheme.forestMedium,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Waypoints Logged',
                      value: '$totalWaypoints',
                      icon: Icons.flag,
                      color: PatrolTheme.amberDark,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: PatrolTheme.errorSurface,
                    borderRadius: PatrolTheme.radiusSm,
                    border: Border.all(color: PatrolTheme.errorBorder),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                        color: PatrolTheme.error, fontSize: 13),
                  ),
                ),

              // List of Completed Sessions
              if (_sessions.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: PatrolTheme.cardDecoration(),
                  child: const Column(
                    children: [
                      Icon(Icons.inbox_outlined,
                          size: 48, color: PatrolTheme.charcoalSubtle),
                      SizedBox(height: 12),
                      Text(
                        'No Synchronized Patrols Found',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: PatrolTheme.charcoal,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Completed patrols synchronized by rangers will appear here.',
                        style: TextStyle(
                          fontSize: 12,
                          color: PatrolTheme.charcoalMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                ...List.generate(_sessions.length, (idx) {
                  final session = _sessions[idx];
                  return _buildSessionReviewCard(session);
                }),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveUnitsTab() {
    FirebaseFirestore? db = widget.controller.firestore;
    try {
      db ??= FirebaseFirestore.instance;
    } catch (_) {
      db = null;
    }

    if (db == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Live unit tracking requires an active Firebase connection.',
            style: TextStyle(color: PatrolTheme.charcoalMuted),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.collection('activePatrolLocations').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: PatrolTheme.forestPrimary),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: PatrolTheme.forestSurface,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.radar,
                        size: 44, color: PatrolTheme.forestPrimary),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Active Field Patrols',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: PatrolTheme.charcoal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'When rangers begin active patrol tracking, their live GPS position, track points, and waypoints stream here in real time.',
                    style: TextStyle(
                      fontSize: 13,
                      color: PatrolTheme.charcoalMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data();
            return _buildLiveUnitCard(data);
          },
        );
      },
    );
  }

  Widget _buildLiveUnitCard(Map<String, dynamic> data) {
    final rangerName = data['rangerName'] as String? ?? 'Ranger';
    final rangerId = data['rangerId'] as String? ?? 'Field Unit';
    final routeName = data['routeName'] as String? ?? 'Assigned Route';
    final lat = (data['latitude'] as num?)?.toDouble() ?? 0.0;
    final lng = (data['longitude'] as num?)?.toDouble() ?? 0.0;
    final accuracy = (data['accuracy'] as num?)?.toDouble();
    final reportedAt = data['reportedAt'] as String?;
    final trackPointsCount = (data['trackPointCount'] as num?)?.toInt() ?? 0;
    final waypointsCount = (data['waypointCount'] as num?)?.toInt() ?? 0;

    String reportedAgo = 'Just now';
    if (reportedAt != null) {
      final dt = DateTime.tryParse(reportedAt);
      if (dt != null) {
        final sec = DateTime.now().toUtc().difference(dt).inSeconds;
        if (sec < 60) {
          reportedAgo = '${sec}s ago';
        } else {
          reportedAgo = '${(sec / 60).round()}m ago';
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: PatrolTheme.cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with live pulsing badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: PatrolTheme.surfaceElevated,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rangerName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: PatrolTheme.charcoal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Route: $routeName • ID: $rangerId',
                        style: const TextStyle(
                          fontSize: 11,
                          color: PatrolTheme.charcoalMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: PatrolTheme.forestSurface,
                    borderRadius: PatrolTheme.radiusFull,
                    border: Border.all(color: PatrolTheme.forestBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: PatrolTheme.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'LIVE • $reportedAgo',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: PatrolTheme.forestDeep,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Map preview of live location
          SizedBox(
            height: 180,
            child: PatrolMapView(
              trackPoints: [
                TrackPoint(
                  latitude: lat,
                  longitude: lng,
                  timestamp: DateTime.now(),
                  accuracy: accuracy ?? 5.0,
                ),
              ],
              currentPosition: LatLng(lat, lng),
              accuracy: accuracy,
              height: 180,
              interactive: true,
              isRanger: false,
            ),
          ),

          // Telemetry Readout
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildDebriefStat(
                  'Coordinates',
                  '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                  Icons.my_location,
                ),
                Container(width: 1, height: 26, color: PatrolTheme.borderLight),
                _buildDebriefStat(
                  'Accuracy',
                  accuracy != null ? '±${accuracy.toStringAsFixed(0)}m' : 'GPS',
                  Icons.gps_fixed,
                ),
                Container(width: 1, height: 26, color: PatrolTheme.borderLight),
                _buildDebriefStat(
                  'Fixes Logged',
                  '$trackPointsCount',
                  Icons.timeline,
                ),
                Container(width: 1, height: 26, color: PatrolTheme.borderLight),
                _buildDebriefStat(
                  'Waypoints',
                  '$waypointsCount',
                  Icons.flag,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: PatrolTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: PatrolTheme.charcoal,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: PatrolTheme.charcoalMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSessionReviewCard(PatrolSession session) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: PatrolTheme.cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: PatrolTheme.surfaceElevated,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.routeName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: PatrolTheme.charcoal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ranger: ${session.rangerId ?? "Unassigned"} • Session: ${session.sessionId.length > 8 ? session.sessionId.substring(0, 8) : session.sessionId}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: PatrolTheme.charcoalMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(
                  label: session.syncMetadata.syncStatus.name.toUpperCase(),
                  color: session.syncMetadata.syncStatus ==
                          SyncStatus.synchronized
                      ? PatrolTheme.success
                      : PatrolTheme.amberDark,
                ),
              ],
            ),
          ),

          // Map preview of recorded GPS path & waypoints
          SizedBox(
            height: 180,
            child: PatrolMapView(
              trackPoints: session.trackPoints,
              checkpoints: session.checkpoints,
              waypoints: session.waypoints,
              deviations: session.deviations,
              height: 180,
              interactive: false,
              isRanger: false,
            ),
          ),

          // Telemetry Readout
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildDebriefStat(
                  'Distance',
                  '${session.recordedDistanceKm.toStringAsFixed(1)} km',
                  Icons.straighten,
                ),
                Container(width: 1, height: 26, color: PatrolTheme.borderLight),
                _buildDebriefStat(
                  'Duration',
                  _formatDuration(session.actualDuration),
                  Icons.timer,
                ),
                Container(width: 1, height: 26, color: PatrolTheme.borderLight),
                _buildDebriefStat(
                  'Waypoints',
                  '${session.waypoints.length}',
                  Icons.flag,
                ),
                Container(width: 1, height: 26, color: PatrolTheme.borderLight),
                _buildDebriefStat(
                  'GPS Points',
                  '${session.trackPoints.length}',
                  Icons.my_location,
                ),
              ],
            ),
          ),

          // Logged Waypoints Inspection
          if (session.waypoints.isNotEmpty) ...[
            const Divider(height: 1, color: PatrolTheme.borderLight),
            Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 14),
                leading: const Icon(Icons.place_outlined,
                    size: 18, color: PatrolTheme.forestPrimary),
                title: Text(
                  'Synchronized Waypoints (${session.waypoints.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: PatrolTheme.charcoal,
                  ),
                ),
                subtitle: const Text(
                  'Tap any waypoint for GPS coordinates, field notes, and photo references',
                  style:
                      TextStyle(fontSize: 11, color: PatrolTheme.charcoalMuted),
                ),
                children: [
                  WaypointListPanel(
                    waypoints: session.waypoints,
                    isRanger: false,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDebriefStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: PatrolTheme.charcoalMuted),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: PatrolTheme.charcoalMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: PatrolTheme.charcoal,
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}
