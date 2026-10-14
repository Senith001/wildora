import 'package:flutter/material.dart';

import '../application/patrol_controller.dart';
import '../data/patrol_models.dart';
import 'patrol_completed_screen.dart';
import 'patrol_map_view.dart';
import 'patrol_theme.dart';
import 'patrol_widgets.dart';

/// Screen displaying the assigned ranger's historical completed patrols.
///
/// Features:
/// - Shows summaries: start/end time, duration, distance, waypoint count.
/// - Full route review with interactive map and recorded waypoints list.
/// - Per-patrol and bulk manual retry sync with clear sync status indicators.
/// - Offline resilience: loads cached sessions locally from durable Hive store.
class RangerPatrolHistoryScreen extends StatefulWidget {
  const RangerPatrolHistoryScreen({super.key, required this.controller});

  final PatrolController controller;

  @override
  State<RangerPatrolHistoryScreen> createState() =>
      _RangerPatrolHistoryScreenState();
}

class _RangerPatrolHistoryScreenState extends State<RangerPatrolHistoryScreen> {
  String? _syncingSessionId;

  @override
  void initState() {
    super.initState();
    widget.controller.loadPatrolHistory();
  }

  Future<void> _syncSingle(PatrolSession session) async {
    setState(() => _syncingSessionId = session.sessionId);
    final success = await widget.controller.syncHistorySession(session);
    if (mounted) {
      setState(() => _syncingSessionId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
              ? 'Patrol synchronized successfully to Cloud Firestore!'
              : 'Sync failed: saved on device for retry.',
          ),
          backgroundColor:
              success ? PatrolTheme.success : PatrolTheme.amberDark,
        ),
      );
    }
  }

  Future<void> _syncAllPending() async {
    final pending = widget.controller.historyCache
        .where((s) => s.syncMetadata.syncStatus != SyncStatus.synchronized)
        .toList();

    if (pending.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All past patrols are already synchronized!'),
          backgroundColor: PatrolTheme.forestPrimary,
        ),
      );
      return;
    }

    int syncedCount = 0;
    for (final session in pending) {
      setState(() => _syncingSessionId = session.sessionId);
      final success = await widget.controller.syncHistorySession(session);
      if (success) syncedCount++;
    }

    if (mounted) {
      setState(() => _syncingSessionId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Synchronized $syncedCount of ${pending.length} patrols.'),
          backgroundColor: PatrolTheme.forestPrimary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final history = widget.controller.historyCache;
        final isLoading = widget.controller.historyLoading;
        final totalDistance = history.fold<double>(
            0.0, (acc, s) => acc + s.recordedDistanceKm);
        final totalWaypoints =
            history.fold<int>(0, (acc, s) => acc + s.waypoints.length);
        final pendingCount = history
            .where((s) => s.syncMetadata.syncStatus != SyncStatus.synchronized)
            .length;

        return Scaffold(
          backgroundColor: PatrolTheme.background,
          appBar: AppBar(
            title: const Text('My Patrol History'),
            backgroundColor: PatrolTheme.forestDeep,
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              if (pendingCount > 0)
                IconButton(
                  icon: const Icon(Icons.cloud_upload_outlined),
                  tooltip: 'Sync All Pending ($pendingCount)',
                  onPressed: widget.controller.isSyncing ? null : _syncAllPending,
                ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh History',
                onPressed: () => widget.controller.loadPatrolHistory(),
              ),
            ],
          ),
          body: SafeArea(
            child: isLoading && history.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(
                        color: PatrolTheme.forestPrimary),
                  )
                : RefreshIndicator(
                    onRefresh: () => widget.controller.loadPatrolHistory(),
                    color: PatrolTheme.forestPrimary,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: ResponsiveContentWrapper(
                        padding: EdgeInsets.zero,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ─── Ranger Summary Banner ────────────────────────
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: PatrolTheme.forestSurface,
                                borderRadius: PatrolTheme.radiusMd,
                                border:
                                    Border.all(color: PatrolTheme.forestBorder),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.military_tech_outlined,
                                      color: PatrolTheme.forestPrimary,
                                      size: 28),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.controller.currentUserName,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: PatrolTheme.forestDeep,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Unit ID: ${widget.controller.currentUserId ?? "Local Unit"} • Completed Missions',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: PatrolTheme.charcoalMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (pendingCount > 0)
                                    StatusBadge(
                                      label: '$pendingCount PENDING SYNC',
                                      color: PatrolTheme.amberDark,
                                    ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 14),

                            // ─── Cumulative Metrics ───────────────────────────
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMetricTile(
                                    label: 'Missions Completed',
                                    value: '${history.length}',
                                    icon: Icons.task_alt,
                                    color: PatrolTheme.forestPrimary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildMetricTile(
                                    label: 'Total Distance',
                                    value:
                                        '${totalDistance.toStringAsFixed(1)} km',
                                    icon: Icons.straighten,
                                    color: PatrolTheme.forestMedium,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildMetricTile(
                                    label: 'Waypoints Recorded',
                                    value: '$totalWaypoints',
                                    icon: Icons.flag,
                                    color: PatrolTheme.amberDark,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // ─── History Patrol Cards ─────────────────────────
                            if (history.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(32),
                                decoration: PatrolTheme.cardDecoration(),
                                child: const Column(
                                  children: [
                                    Icon(Icons.history_toggle_off,
                                        size: 48,
                                        color: PatrolTheme.charcoalSubtle),
                                    SizedBox(height: 12),
                                    Text(
                                      'No Completed Patrols Yet',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: PatrolTheme.charcoal,
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      'When you complete assigned patrols, your missions, GPS tracks, and observation waypoints will be archived here.',
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
                              ...List.generate(history.length, (idx) {
                                final session = history[idx];
                                return _buildHistoryCard(session);
                              }),

                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        );
      },
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
              fontSize: 17,
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

  Widget _buildHistoryCard(PatrolSession session) {
    final isSynced =
        session.syncMetadata.syncStatus == SyncStatus.synchronized;
    final isSyncingThis = _syncingSessionId == session.sessionId;

    final startTimeStr = session.startTime != null
        ? '${session.startTime!.toLocal().hour.toString().padLeft(2, '0')}:${session.startTime!.toLocal().minute.toString().padLeft(2, '0')}'
        : '--:--';
    final endTimeStr = session.endTime != null
        ? '${session.endTime!.toLocal().hour.toString().padLeft(2, '0')}:${session.endTime!.toLocal().minute.toString().padLeft(2, '0')}'
        : '--:--';
    final dateStr = (session.endTime ?? session.startTime ?? DateTime.now())
        .toLocal()
        .toIso8601String()
        .substring(0, 10);

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
                        '$dateStr • $startTimeStr – $endTimeStr',
                        style: const TextStyle(
                          fontSize: 11,
                          color: PatrolTheme.charcoalMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(
                  label: isSynced ? 'SYNCED' : 'PENDING SYNC',
                  color:
                      isSynced ? PatrolTheme.success : PatrolTheme.amberDark,
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
              isRanger: true,
            ),
          ),

          // Telemetry Readout
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'Distance',
                  '${session.recordedDistanceKm.toStringAsFixed(1)} km',
                  Icons.straighten,
                ),
                Container(width: 1, height: 24, color: PatrolTheme.borderLight),
                _buildStatItem(
                  'Duration',
                  _formatDuration(session.actualDuration),
                  Icons.timer_outlined,
                ),
                Container(width: 1, height: 24, color: PatrolTheme.borderLight),
                _buildStatItem(
                  'Waypoints',
                  '${session.waypoints.length}',
                  Icons.flag_outlined,
                ),
                Container(width: 1, height: 24, color: PatrolTheme.borderLight),
                _buildStatItem(
                  'GPS Fixes',
                  '${session.trackPoints.length}',
                  Icons.my_location,
                ),
              ],
            ),
          ),

          // Waypoints expansion preview if any
          if (session.waypoints.isNotEmpty) ...[
            const Divider(height: 1, color: PatrolTheme.borderLight),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 14),
                leading: const Icon(Icons.place_outlined,
                    size: 18, color: PatrolTheme.forestPrimary),
                title: Text(
                  'Recorded Waypoints (${session.waypoints.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: PatrolTheme.charcoal,
                  ),
                ),
                subtitle: const Text(
                  'Tap any waypoint to view field coordinates and notes',
                  style:
                      TextStyle(fontSize: 11, color: PatrolTheme.charcoalMuted),
                ),
                children: [
                  WaypointListPanel(
                    waypoints: session.waypoints,
                    isRanger: true,
                  ),
                ],
              ),
            ),
          ],

          // Footer actions
          const Divider(height: 1, color: PatrolTheme.borderLight),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PatrolCompletedScreen(
                            controller: widget.controller,
                            session: session,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.summarize_outlined, size: 16),
                    label: const Text('View Summary'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: PatrolTheme.forestPrimary,
                      side: const BorderSide(color: PatrolTheme.forestBorder),
                    ),
                  ),
                ),
                if (!isSynced) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: isSyncingThis ? null : () => _syncSingle(session),
                      icon: isSyncingThis
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.cloud_upload, size: 16),
                      label: Text(isSyncingThis ? 'Syncing…' : 'Retry Sync'),
                      style: FilledButton.styleFrom(
                        backgroundColor: PatrolTheme.amberDark,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
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
        const SizedBox(height: 2),
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
