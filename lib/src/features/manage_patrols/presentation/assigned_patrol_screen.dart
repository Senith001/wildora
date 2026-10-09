import 'package:flutter/material.dart';

import '../application/patrol_controller.dart';
import '../data/patrol_models.dart';
import 'patrol_in_progress_screen.dart';
import 'patrol_widgets.dart';

/// Screen 1: Assigned Patrol
///
/// Displays the assigned patrol route, ranger details, and a Start Patrol
/// action. Handles offline caching, duplicate session prevention, and
/// active patrol resumption.
class AssignedPatrolScreen extends StatefulWidget {
  const AssignedPatrolScreen({super.key, required this.controller});

  final PatrolController controller;

  @override
  State<AssignedPatrolScreen> createState() => _AssignedPatrolScreenState();
}

class _AssignedPatrolScreenState extends State<AssignedPatrolScreen> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController() async {
    await widget.controller.initialize();
    if (widget.controller.currentSession == null) {
      await widget.controller.loadAssignment();
    }
    if (mounted) {
      setState(() => _initialized = true);
      // If there's an active patrol already, offer to resume
      if (widget.controller.currentSession?.lifecycleStatus ==
          PatrolLifecycleStatus.active) {
        _showResumeDialog();
      }
    }
  }

  void _showResumeDialog() {
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Active Patrol Found'),
        content: const Text(
          'You have an active patrol in progress. Would you like to resume it?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay Here'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Resume Patrol'),
          ),
        ],
      ),
    ).then((resume) {
      if (resume == true && mounted) {
        _navigateToInProgress();
      }
    });
  }

  Future<void> _startPatrol() async {
    final success = await widget.controller.startPatrol();
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Patrol started successfully!'),
          backgroundColor: Color(0xFF2E7D32),
          duration: Duration(seconds: 2),
        ),
      );
      _navigateToInProgress();
    } else if (mounted && widget.controller.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.controller.error!),
          backgroundColor: Colors.red.shade700,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _startPatrol,
          ),
        ),
      );
    }
  }

  void _navigateToInProgress() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PatrolInProgressScreen(controller: widget.controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final session = widget.controller.currentSession;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Assigned Patrol'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back to Home',
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              // Connectivity indicator
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ConnectivityBadge(
                  isOnline: widget.controller.isOnline,
                ),
              ),
            ],
          ),
          body: !_initialized || widget.controller.isLoading
              ? const Center(child: CircularProgressIndicator())
              : session == null
                  ? _buildError(theme)
                  : _buildContent(context, session, theme, colors),
        );
      },
    );
  }

  Widget _buildError(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              widget.controller.error ?? 'Failed to load patrol assignment.',
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () async {
                await widget.controller.loadAssignment();
                if (mounted) setState(() {});
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    PatrolSession session,
    ThemeData theme,
    ColorScheme colors,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Route name header card
          Card(
            color: colors.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.map_outlined, size: 48,
                      color: colors.onPrimaryContainer),
                  const SizedBox(height: 12),
                  Text(
                    session.routeName,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  StatusBadge(
                    label: session.lifecycleStatus.name.toUpperCase(),
                    color: _statusColor(session.lifecycleStatus),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Route preview map placeholder
          Card(
            clipBehavior: Clip.antiAlias,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.primaryContainer.withValues(alpha: 0.3),
                    colors.secondaryContainer.withValues(alpha: 0.5),
                  ],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.terrain, size: 48,
                        color: colors.primary.withValues(alpha: 0.6)),
                    const SizedBox(height: 8),
                    Text(
                      'Route Preview',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      'Map visualization available during patrol',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Assignment details
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assignment Details',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DetailRow(
                    icon: Icons.route,
                    label: 'Route ID',
                    value: session.assignedRouteId,
                  ),
                  DetailRow(
                    icon: Icons.person,
                    label: 'Ranger ID',
                    value: session.rangerId ?? 'Not assigned',
                  ),
                  DetailRow(
                    icon: Icons.straighten,
                    label: 'Planned Distance',
                    value: '${session.plannedDistanceKm.toStringAsFixed(1)} km',
                  ),
                  DetailRow(
                    icon: Icons.timer,
                    label: 'Estimated Duration',
                    value: _formatMinutes(session.estimatedDurationMinutes),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Sync status
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  SyncStatusIcon(
                    status: session.syncMetadata.syncStatus,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sync Status',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        Text(
                          _syncLabel(session.syncMetadata.syncStatus),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Start Patrol button
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: widget.controller.isLoading ? null : _startPatrol,
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              icon: const Icon(Icons.play_arrow, size: 28),
              label: const Text('Start Patrol'),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Color _statusColor(PatrolLifecycleStatus status) {
    switch (status) {
      case PatrolLifecycleStatus.assigned:
        return Colors.blue;
      case PatrolLifecycleStatus.active:
        return const Color(0xFF2E7D32);
      case PatrolLifecycleStatus.completed:
        return Colors.grey;
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

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}min';
    if (h > 0) return '${h}h';
    return '${m}min';
  }
}
