import 'package:flutter/material.dart';

import '../application/patrol_controller.dart';
import '../data/patrol_models.dart';
import 'assigned_patrol_screen.dart';
import 'patrol_widgets.dart';

/// Screen 4: Patrol Completed Summary
///
/// Displays the final patrol statistics, sync status, and navigation actions
/// after a successful patrol completion.
class PatrolCompletedScreen extends StatelessWidget {
  const PatrolCompletedScreen({super.key, required this.controller});

  final PatrolController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final theme = Theme.of(context);
        final session = controller.currentSession;
        if (session == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Patrol Summary')),
            body: const Center(child: Text('No session data available.')),
          );
        }

        final syncStatus = session.syncMetadata.syncStatus;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Patrol Summary'),
            automaticallyImplyLeading: false,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Completed header
                Card(
                  color: const Color(0xFF2E7D32),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 56,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Patrol Completed',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'Session: ${session.sessionId.substring(0, 12)}…',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Time details
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Timing',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DetailRow(
                          icon: Icons.play_circle,
                          label: 'Start Time',
                          value: session.startTime != null
                              ? _formatDateTime(session.startTime!)
                              : 'N/A',
                        ),
                        DetailRow(
                          icon: Icons.stop_circle,
                          label: 'End Time',
                          value: session.endTime != null
                              ? _formatDateTime(session.endTime!)
                              : 'N/A',
                        ),
                        DetailRow(
                          icon: Icons.timer,
                          label: 'Actual Duration',
                          value: _formatDuration(session.actualDuration),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Track summary
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Track Summary',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DetailRow(
                          icon: Icons.straighten,
                          label: 'Recorded GPS Distance',
                          value:
                              '${session.recordedDistanceKm.toStringAsFixed(2)} km',
                        ),
                        DetailRow(
                          icon: Icons.location_on,
                          label: 'GPS Points Recorded',
                          value: '${session.trackPoints.length}',
                        ),
                        DetailRow(
                          icon: Icons.flag,
                          label: 'Waypoints Saved',
                          value: '${session.waypoints.length}',
                        ),
                        DetailRow(
                          icon: Icons.alt_route,
                          label: 'Route Deviations',
                          value: '${session.deviations.length}',
                        ),
                        // Coverage note
                        if (session.hasGpsGaps) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.amber.shade300),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.warning_amber,
                                    color: Colors.amber.shade800, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'GPS recording gaps detected. '
                                    'Route coverage may be incomplete.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.amber.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Status cards
                Row(
                  children: [
                    Expanded(
                      child: _StatusCard(
                        icon: Icons.check_circle,
                        label: 'Patrol Status',
                        value: 'Completed',
                        color: const Color(0xFF2E7D32),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatusCard(
                        icon: _syncIcon(syncStatus),
                        label: 'Sync Status',
                        value: _syncLabel(syncStatus),
                        color: _syncColor(syncStatus),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Sync explanation
                if (syncStatus == SyncStatus.pendingSync &&
                    !controller.isOnline)
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.cloud_off, color: Colors.blue.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'This record is saved locally but is not yet '
                              'confirmed as available to management. It will '
                              'sync when connectivity is restored.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (syncStatus == SyncStatus.syncFailed)
                  Card(
                    color: Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.sync_problem,
                                  color: Colors.red.shade700),
                              const SizedBox(width: 8),
                              Text(
                                'Sync Failed',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade900,
                                ),
                              ),
                            ],
                          ),
                          if (session.syncMetadata.lastSyncError != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              session.syncMetadata.lastSyncError!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red.shade800,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                // Action buttons
                if (syncStatus != SyncStatus.synchronized)
                  SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: controller.isSyncing
                          ? null
                          : () => controller.syncCurrentSession(),
                      icon: controller.isSyncing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync),
                      label: Text(controller.isSyncing
                          ? 'Syncing…'
                          : syncStatus == SyncStatus.syncFailed
                              ? 'Retry Sync'
                              : 'Sync Now'),
                    ),
                  ),

                const SizedBox(height: 12),

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
                    icon: const Icon(Icons.assignment),
                    label: const Text('New Patrol Assignment'),
                  ),
                ),

                const SizedBox(height: 8),

                SizedBox(
                  height: 48,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    icon: const Icon(Icons.home),
                    label: const Text('Return to Home'),
                  ),
                ),

                const SizedBox(height: 16),
              ],
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

  IconData _syncIcon(SyncStatus status) {
    switch (status) {
      case SyncStatus.pendingSync:
        return Icons.cloud_upload;
      case SyncStatus.synchronized:
        return Icons.cloud_done;
      case SyncStatus.syncFailed:
        return Icons.sync_problem;
    }
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
        return Colors.blue;
      case SyncStatus.synchronized:
        return const Color(0xFF2E7D32);
      case SyncStatus.syncFailed:
        return Colors.red;
    }
  }
}

// ─── Status card ────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  const _StatusCard({
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
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
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
