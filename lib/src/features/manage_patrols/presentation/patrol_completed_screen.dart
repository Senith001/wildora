import 'package:flutter/material.dart';

import '../application/patrol_controller.dart';
import '../data/patrol_models.dart';
import 'assigned_patrol_screen.dart';
import 'patrol_map_view.dart';
import 'patrol_theme.dart';
import 'patrol_widgets.dart';
import 'ranger_patrol_history_screen.dart';

/// Screen 4: Patrol Completed Summary
///
/// Post-patrol operational debrief screen presenting final field statistics,
/// timing, durable local storage confirmation, GPS continuity assessment,
/// and cloud sync state.
class PatrolCompletedScreen extends StatelessWidget {
  const PatrolCompletedScreen({
    super.key,
    required this.controller,
    this.session,
  });

  final PatrolController controller;
  final PatrolSession? session;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final session = this.session ?? controller.currentSession;
        if (session == null) {
          return Scaffold(
            backgroundColor: PatrolTheme.background,
            appBar: AppBar(
              title: const Text('Patrol Summary'),
              backgroundColor: PatrolTheme.forestDeep,
              foregroundColor: Colors.white,
            ),
            body: const Center(
              child: Text(
                'No session data available.',
                style: TextStyle(color: PatrolTheme.charcoalMuted),
              ),
            ),
          );
        }

        final syncStatus = session.syncMetadata.syncStatus;

        return Scaffold(
          backgroundColor: PatrolTheme.background,
          appBar: AppBar(
            title: const Text('Patrol Summary'),
            backgroundColor: PatrolTheme.forestDeep,
            foregroundColor: Colors.white,
            elevation: 0,
            automaticallyImplyLeading: this.session != null,
            actions: [
              IconButton(
                icon: const Icon(Icons.history),
                tooltip: 'My Patrol History',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          RangerPatrolHistoryScreen(controller: controller),
                    ),
                  );
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: ResponsiveContentWrapper(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ─── Header Card: Patrol Completed ────────────────────────
                  Container(
                    decoration: PatrolTheme.cardDecoration(
                      backgroundColor: PatrolTheme.forestDeep,
                    ),
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle,
                            size: 44,
                            color: Color(0xFF4ADE80),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Patrol Completed',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          session.routeName,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: PatrolTheme.radiusFull,
                          ),
                          child: Text(
                            'Session ID: ${session.sessionId.length > 16 ? session.sessionId.substring(0, 16) : session.sessionId}…',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ─── Local Storage Guarantee Banner ───────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: PatrolTheme.successSurface,
                      borderRadius: PatrolTheme.radiusMd,
                      border: Border.all(color: PatrolTheme.successBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_user_outlined,
                            color: PatrolTheme.success, size: 22),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Saved Locally on Device',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: PatrolTheme.success,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Durable encrypted Hive storage committed. Data is secure even without network.',
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

                  // ─── Patrol Track Map ────────────────────────────────────
                  OperationalCard(
                    title: 'Patrol Track & Coverage Map',
                    icon: Icons.map_outlined,
                    child: PatrolMapView(
                      trackPoints: session.trackPoints,
                      checkpoints: session.checkpoints,
                      waypoints: session.waypoints,
                      deviations: session.deviations,
                      height: 220,
                      interactive: true,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ─── Key Field Telemetry Grid ─────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryStatCard(
                          icon: Icons.timer,
                          label: 'Actual Duration',
                          value: _formatDuration(session.actualDuration),
                          color: PatrolTheme.forestPrimary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SummaryStatCard(
                          icon: Icons.straighten,
                          label: 'Recorded GPS',
                          value:
                              '${session.recordedDistanceKm.toStringAsFixed(2)} km',
                          color: PatrolTheme.forestMedium,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: _SummaryStatCard(
                          icon: Icons.flag_outlined,
                          label: 'Waypoints Saved',
                          value: '${session.waypoints.length}',
                          color: PatrolTheme.amberDark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SummaryStatCard(
                          icon: Icons.alt_route,
                          label: 'Deviations',
                          value: '${session.deviations.length}',
                          color: PatrolTheme.infoBlue,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ─── Detailed Operational Log Card ────────────────────────
                  OperationalCard(
                    title: 'Operational Debrief Log',
                    icon: Icons.fact_check_outlined,
                    child: Column(
                      children: [
                        DetailRow(
                          icon: Icons.play_arrow_outlined,
                          label: 'Patrol Departure',
                          value: session.startTime != null
                              ? _formatDateTime(session.startTime!)
                              : 'Not recorded',
                        ),
                        DetailRow(
                          icon: Icons.stop_circle_outlined,
                          label: 'Patrol Completion',
                          value: session.endTime != null
                              ? _formatDateTime(session.endTime!)
                              : 'Not recorded',
                        ),
                        DetailRow(
                          icon: Icons.my_location,
                          label: 'Accepted GPS Fixes',
                          value: '${session.trackPoints.length} points',
                        ),
                        DetailRow(
                          icon: Icons.trending_up,
                          label: 'Distance Ratio',
                          value:
                              '${session.recordedDistanceKm.toStringAsFixed(1)} / ${session.plannedDistanceKm.toStringAsFixed(1)} km',
                        ),
                        const SizedBox(height: 8),

                        // GPS Gap Continuity Check
                        if (session.hasGpsGaps)
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: PatrolTheme.amberSurface,
                              borderRadius: PatrolTheme.radiusSm,
                              border: Border.all(color: PatrolTheme.amberBorder),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    color: PatrolTheme.amberDark, size: 20),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'GPS recording gaps (≥5m) detected. Segments were safely excluded from travel distance.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: PatrolTheme.amberDark,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: PatrolTheme.forestSurface,
                              borderRadius: PatrolTheme.radiusSm,
                              border: Border.all(color: PatrolTheme.forestBorder),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.verified,
                                    color: PatrolTheme.forestPrimary, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Continuous GPS fix coverage verified across patrol route.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: PatrolTheme.forestPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ─── Cloud Synchronization Status ─────────────────────────
                  OperationalCard(
                    title: 'Central Cloud Synchronization',
                    icon: Icons.cloud_sync_outlined,
                    trailing: StatusBadge(
                      label: _syncLabel(syncStatus).toUpperCase(),
                      color: _syncColor(syncStatus),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (syncStatus == SyncStatus.synchronized)
                          const Row(
                            children: [
                              Icon(Icons.cloud_done,
                                  color: PatrolTheme.success, size: 20),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Session fully synchronized with Wildora Cloud Firestore.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: PatrolTheme.charcoal,
                                  ),
                                ),
                              ),
                            ],
                          )
                        else if (syncStatus == SyncStatus.pendingSync)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                controller.isOnline
                                    ? 'Local session ready for immediate upload to headquarters.'
                                    : 'Saved securely on device. Upload will automatically process when connectivity resumes.',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: PatrolTheme.charcoalMuted,
                                ),
                              ),
                            ],
                          )
                        else if (syncStatus == SyncStatus.syncFailed)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                session.syncMetadata.lastSyncError ??
                                    'Cloud transmission encountered a network or timeout error.',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: PatrolTheme.error,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ─── Recorded Field Waypoints ─────────────────────────────
                  if (session.waypoints.isNotEmpty) ...[
                    OperationalCard(
                      title:
                          'Recorded Field Waypoints (${session.waypoints.length})',
                      icon: Icons.flag_outlined,
                      child: WaypointListPanel(
                        waypoints: session.waypoints,
                        isRanger: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  const SizedBox(height: 14),

                  // ─── Primary Action Buttons ───────────────────────────────
                  if (syncStatus != SyncStatus.synchronized) ...[
                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: controller.isSyncing
                            ? null
                            : () => controller.syncCurrentSession(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: PatrolTheme.forestPrimary,
                          side: const BorderSide(
                              color: PatrolTheme.forestPrimary, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: PatrolTheme.radiusMd,
                          ),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        icon: controller.isSyncing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: PatrolTheme.forestPrimary,
                                ),
                              )
                            : const Icon(Icons.sync, size: 20),
                        label: Text(
                          controller.isSyncing
                              ? 'Syncing…'
                              : syncStatus == SyncStatus.syncFailed
                                  ? 'Retry Sync'
                                  : 'Sync Now',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // New Patrol Assignment Button
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: () async {
                        await controller.resetForNewAssignment();
                        if (context.mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AssignedPatrolScreen(
                                controller: controller,
                              ),
                            ),
                          );
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: PatrolTheme.forestPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: PatrolTheme.radiusMd,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      icon: const Icon(Icons.assignment_outlined, size: 20),
                      label: const Text('New Patrol Assignment'),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // View All Patrol History Button
                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                RangerPatrolHistoryScreen(controller: controller),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: PatrolTheme.forestPrimary,
                        side: const BorderSide(color: PatrolTheme.forestBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: PatrolTheme.radiusMd,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      icon: const Icon(Icons.history, size: 20),
                      label: const Text('View All Patrol History'),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Return to Home
                  SizedBox(
                    height: 48,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: PatrolTheme.charcoalMuted,
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      icon: const Icon(Icons.home_outlined, size: 20),
                      label: const Text('Return to Home'),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDateTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    return '$d/$mo/${dt.year} $h:$m';
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  String _syncLabel(SyncStatus status) {
    switch (status) {
      case SyncStatus.pendingSync:
        return 'Pending Sync';
      case SyncStatus.synchronized:
        return 'Synchronized';
      case SyncStatus.syncFailed:
        return 'Sync Failed';
    }
  }

  Color _syncColor(SyncStatus status) {
    switch (status) {
      case SyncStatus.pendingSync:
        return PatrolTheme.infoBlue;
      case SyncStatus.synchronized:
        return PatrolTheme.success;
      case SyncStatus.syncFailed:
        return PatrolTheme.error;
    }
  }
}

class _SummaryStatCard extends StatelessWidget {
  const _SummaryStatCard({
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
    return Container(
      decoration: PatrolTheme.cardDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: PatrolTheme.charcoalMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: PatrolTheme.charcoal,
            ),
          ),
        ],
      ),
    );
  }
}
