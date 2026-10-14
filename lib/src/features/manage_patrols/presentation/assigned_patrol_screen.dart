import 'package:flutter/material.dart';

import '../application/patrol_controller.dart';
import '../data/patrol_models.dart';
import 'assign_patrol_screen.dart';
import 'manager_patrol_review_screen.dart';
import 'patrol_auth_screen.dart';
import 'patrol_completed_screen.dart';
import 'patrol_in_progress_screen.dart';
import 'patrol_map_view.dart';
import 'patrol_theme.dart';
import 'patrol_widgets.dart';
import 'ranger_patrol_history_screen.dart';

/// Screen 1: Assigned Patrol
///
/// Displays the ranger's assigned route, area details, planned metrics,
/// interactive route preview with real OpenStreetMap checkpoints, and Start/Resume action.
/// Handles offline caching, duplicate session prevention, role authorization,
/// and Park Manager route assignment navigation.
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
    if (widget.controller.currentSession == null ||
        widget.controller.availableAssignments.isEmpty) {
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
        backgroundColor: PatrolTheme.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: PatrolTheme.radiusMd),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: PatrolTheme.amberSurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.directions_run,
                  color: PatrolTheme.amberDark, size: 22),
            ),
            const SizedBox(width: 12),
            const Text(
              'Active Patrol Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: PatrolTheme.charcoal,
              ),
            ),
          ],
        ),
        content: const Text(
          'You have an active patrol session in progress. Would you like to resume tracking it now?',
          style: TextStyle(color: PatrolTheme.charcoalMuted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay Here'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx, true);
              _navigateToInProgress();
            },
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('Resume Patrol'),
            style: FilledButton.styleFrom(
              backgroundColor: PatrolTheme.forestPrimary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startPatrol() async {
    final success = await widget.controller.startPatrol();
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Patrol started successfully! Tracking GPS.'),
          backgroundColor: PatrolTheme.forestPrimary,
          duration: Duration(seconds: 2),
        ),
      );
      _navigateToInProgress();
    } else if (mounted && widget.controller.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.controller.error!),
          backgroundColor: PatrolTheme.error,
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
        builder: (_) => PatrolInProgressScreen(controller: widget.controller),
      ),
    );
  }

  Future<void> _openAuthScreen() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PatrolAuthScreen(controller: widget.controller),
      ),
    );
    if (result == true && mounted) {
      await widget.controller.initialize();
      await widget.controller.loadAssignment();
      setState(() {});
    }
  }

  Future<void> _signOut() async {
    await widget.controller.signOut();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final session = widget.controller.currentSession;

        return Scaffold(
          backgroundColor: PatrolTheme.background,
          appBar: AppBar(
            title: const Text('Assigned Patrol'),
            backgroundColor: PatrolTheme.forestDeep,
            foregroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back to Home',
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.history),
                tooltip: 'My Patrol History',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          RangerPatrolHistoryScreen(controller: widget.controller),
                    ),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GpsStatusBadge(
                  available: widget.controller.gpsAvailable,
                  lastFix: widget.controller.lastGpsFix,
                  status: widget.controller.gpsSignalStatus,
                  accuracy: widget.controller.gpsAccuracy,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ConnectivityBadge(
                  isOnline: widget.controller.isOnline,
                ),
              ),
            ],
          ),
          body: !_initialized || widget.controller.isLoading
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                          color: PatrolTheme.forestPrimary),
                      SizedBox(height: 16),
                      Text(
                        'Loading assigned patrol route…',
                        style: TextStyle(
                          color: PatrolTheme.charcoalMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : session == null
                  ? _buildEmptyState()
                  : _buildContent(context, session),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final isAuthenticated = widget.controller.currentUserId != 'unauthenticated';
    final isManager = widget.controller.isManager;

    return Center(
      child: ResponsiveContentWrapper(
        child: OperationalCard(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isAuthenticated
                      ? PatrolTheme.forestSurface
                      : PatrolTheme.amberSurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isAuthenticated
                      ? Icons.assignment_late_outlined
                      : Icons.lock_outline,
                  size: 48,
                  color: isAuthenticated
                      ? PatrolTheme.forestPrimary
                      : PatrolTheme.amberDark,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isAuthenticated
                    ? 'No Assigned Patrol Route Found'
                    : 'Sign In Required for Patrol Access',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: PatrolTheme.charcoal,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                !isAuthenticated
                    ? 'You must sign in with an authorized Ranger or Park Manager account to access patrol assignments.'
                    : (widget.controller.error ??
                        'No patrol assignment is currently assigned to your UID (${widget.controller.currentUserId}). Please ask your Park Manager to assign a patrol route.'),
                style: const TextStyle(
                  color: PatrolTheme.charcoalMuted,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (!isAuthenticated)
                FilledButton.icon(
                  onPressed: _openAuthScreen,
                  icon: const Icon(Icons.login),
                  label: const Text('Sign In to Wildora'),
                  style: FilledButton.styleFrom(
                    backgroundColor: PatrolTheme.forestPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                )
              else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _openAuthScreen,
                      icon: const Icon(Icons.manage_accounts, size: 16),
                      label: const Text('Account'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: PatrolTheme.forestPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () async {
                        await widget.controller.loadAssignment();
                        if (mounted) setState(() {});
                      },
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Reload Assignment'),
                      style: FilledButton.styleFrom(
                        backgroundColor: PatrolTheme.forestPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                      ),
                    ),
                  ],
                ),
                if (isManager) ...[
                  const SizedBox(height: 16),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AssignPatrolScreen(
                            controller: widget.controller,
                          ),
                        ),
                      ).then((_) {
                        widget.controller.loadAssignment();
                      });
                    },
                    icon: const Icon(Icons.add_location_alt, size: 16),
                    label: const Text('Dispatch / Assign New Patrol'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, PatrolSession session) {
    final isActive = session.lifecycleStatus == PatrolLifecycleStatus.active;
    final isManager = widget.controller.isManager;

    return SingleChildScrollView(
      child: ResponsiveContentWrapper(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Identity & Role Banner ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isManager
                    ? PatrolTheme.amberSurface
                    : PatrolTheme.forestSurface,
                borderRadius: PatrolTheme.radiusMd,
                border: Border.all(
                  color: isManager
                      ? PatrolTheme.amberBorder
                      : PatrolTheme.forestBorder,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isManager ? Icons.admin_panel_settings : Icons.shield,
                    size: 20,
                    color: isManager
                        ? PatrolTheme.amberDark
                        : PatrolTheme.forestPrimary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isManager
                              ? 'Role: Park Manager / Dispatch'
                              : 'Signed in: ${widget.controller.currentUserName}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isManager
                                ? PatrolTheme.amberDark
                                : PatrolTheme.forestDeep,
                          ),
                        ),
                        Text(
                          'UID: ${widget.controller.currentUserId}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: PatrolTheme.charcoalMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton.icon(
                        onPressed: _openAuthScreen,
                        icon: const Icon(Icons.manage_accounts, size: 14),
                        label: const Text('Account',
                            style: TextStyle(fontSize: 11)),
                        style: TextButton.styleFrom(
                          foregroundColor: isManager
                              ? PatrolTheme.amberDark
                              : PatrolTheme.forestPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _signOut,
                        icon: const Icon(Icons.logout, size: 14),
                        label: const Text('Sign Out',
                            style: TextStyle(fontSize: 11)),
                        style: TextButton.styleFrom(
                          foregroundColor: PatrolTheme.charcoalMuted,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ─── Manager Quick-Action Bar (if Manager role) ─────────────────
            if (isManager) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: PatrolTheme.cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.tune,
                            size: 16, color: PatrolTheme.forestPrimary),
                        SizedBox(width: 8),
                        Text(
                          'Manager Dispatch Controls',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: PatrolTheme.charcoal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AssignPatrolScreen(
                                    controller: widget.controller,
                                  ),
                                ),
                              ).then((_) {
                                widget.controller.loadAssignment();
                              });
                            },
                            icon: const Icon(Icons.add_location_alt, size: 16),
                            label: const Text('Assign Route'),
                            style: FilledButton.styleFrom(
                              backgroundColor: PatrolTheme.forestPrimary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              textStyle: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ManagerPatrolReviewScreen(
                                    controller: widget.controller,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.analytics_outlined, size: 16),
                            label: const Text('Review Coverage'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: PatrolTheme.forestPrimary,
                              side: const BorderSide(
                                  color: PatrolTheme.forestBorder),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              textStyle: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ─── Multiple Assignments Selector ──────────────────────────────
            if (widget.controller.availableAssignments.length > 1) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children:
                      widget.controller.availableAssignments.map((assignment) {
                    final isSelected =
                        widget.controller.selectedAssignment?.id ==
                            assignment.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(assignment.routeName),
                        selected: isSelected,
                        selectedColor: PatrolTheme.forestPrimary,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : PatrolTheme.charcoal,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 12,
                        ),
                        onSelected: (_) =>
                            widget.controller.selectAssignment(assignment),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ─── Route Identity Banner ──────────────────────────────────────
            Container(
              decoration: PatrolTheme.cardDecoration(
                backgroundColor: PatrolTheme.surfaceCard,
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: PatrolTheme.forestSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: PatrolTheme.forestBorder),
                        ),
                        child: const Icon(
                          Icons.alt_route,
                          size: 28,
                          color: PatrolTheme.forestPrimary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    session.routeName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: PatrolTheme.charcoal,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                                StatusBadge(
                                  label: session.lifecycleStatus.name
                                      .toUpperCase(),
                                  color: _statusColor(session.lifecycleStatus),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${session.checkpoints.length} Checkpoints Planned • Buffer Zone Field Sector',
                              style: const TextStyle(
                                fontSize: 13,
                                color: PatrolTheme.charcoalSubtle,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ─── Tactical OpenStreetMap Route Preview ───────────────────────
            PatrolMapView(
              trackPoints: session.trackPoints,
              checkpoints: session.checkpoints,
              waypoints: session.waypoints,
              height: 220,
              interactive: true,
            ),

            const SizedBox(height: 14),

            // ─── Assignment Details & Metadata ──────────────────────────────
            OperationalCard(
              title: 'Operational Specifications',
              icon: Icons.assignment_outlined,
              child: Column(
                children: [
                  DetailRow(
                    icon: Icons.fingerprint,
                    label: 'Session ID',
                    value: session.sessionId.length > 12
                        ? '${session.sessionId.substring(0, 12)}…'
                        : session.sessionId,
                  ),
                  DetailRow(
                    icon: Icons.tag,
                    label: 'Assigned Route Code',
                    value: session.assignedRouteId,
                  ),
                  DetailRow(
                    icon: Icons.badge_outlined,
                    label: 'Ranger Assigned',
                    value: session.rangerId ?? 'R-4089 (Field Unit)',
                  ),
                  const Divider(height: 16, color: PatrolTheme.borderLight),
                  DetailRow(
                    icon: Icons.straighten,
                    label: 'Planned Distance',
                    value:
                        '${session.plannedDistanceKm.toStringAsFixed(1)} km',
                    badge: _buildEstimatePill('PLANNED'),
                  ),
                  DetailRow(
                    icon: Icons.timer_outlined,
                    label: 'Estimated Duration',
                    value: _formatMinutes(session.estimatedDurationMinutes),
                    badge: _buildEstimatePill('ESTIMATE'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ─── Local Storage & Sync Status ────────────────────────────────
            OperationalCard(
              title: 'Durable Local Persistence',
              icon: Icons.save_outlined,
              child: Row(
                children: [
                  SyncStatusIcon(status: session.syncMetadata.syncStatus),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Encrypted Local Storage (Hive DB)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: PatrolTheme.charcoal,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Version Rev ${session.revision} • Status: ${_syncLabel(session.syncMetadata.syncStatus)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: PatrolTheme.charcoalMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ─── Recorded Waypoints ─────────────────────────────────────
            if (session.waypoints.isNotEmpty) ...[
              const SizedBox(height: 14),
              OperationalCard(
                title: 'Recorded Waypoints (${session.waypoints.length})',
                icon: Icons.flag_outlined,
                child: WaypointListPanel(
                  waypoints: session.waypoints,
                  isRanger: true,
                ),
              ),
            ],

            const SizedBox(height: 24),

            // ─── Primary Action Button (Start / Resume / Completed) ────────────────────
            Builder(
              builder: (context) {
                final isCompleted =
                    session.lifecycleStatus == PatrolLifecycleStatus.completed;

                if (isCompleted) {
                  return Column(
                    children: [
                      SizedBox(
                        height: 54,
                        width: double.infinity,
                        child: FilledButton.icon(
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
                          style: FilledButton.styleFrom(
                            backgroundColor: PatrolTheme.forestMedium,
                            foregroundColor: Colors.white,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: PatrolTheme.radiusMd,
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          icon: const Icon(Icons.task_alt, size: 22),
                          label: const Text('Patrol Completed • View Summary'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 48,
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RangerPatrolHistoryScreen(
                                  controller: widget.controller,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.history, size: 18),
                          label: const Text('View All Completed Patrols'),
                        ),
                      ),
                    ],
                  );
                }

                return SizedBox(
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: widget.controller.isLoading
                        ? null
                        : (isActive ? _navigateToInProgress : _startPatrol),
                    style: FilledButton.styleFrom(
                      backgroundColor: isActive
                          ? PatrolTheme.amberDark
                          : PatrolTheme.forestPrimary,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: PatrolTheme.radiusMd,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    icon: const Icon(
                      Icons.play_arrow,
                      size: 24,
                    ),
                    label: Text(isActive ? 'Resume Patrol' : 'Start Patrol'),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildEstimatePill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: PatrolTheme.forestSurface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: PatrolTheme.forestBorder, width: 0.8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: PatrolTheme.forestPrimary,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Color _statusColor(PatrolLifecycleStatus status) {
    switch (status) {
      case PatrolLifecycleStatus.assigned:
        return PatrolTheme.infoBlue;
      case PatrolLifecycleStatus.active:
        return PatrolTheme.success;
      case PatrolLifecycleStatus.completed:
        return PatrolTheme.charcoalSubtle;
    }
  }

  String _syncLabel(SyncStatus status) {
    switch (status) {
      case SyncStatus.pendingSync:
        return 'Pending Cloud Sync';
      case SyncStatus.synchronized:
        return 'Synchronized to Cloud';
      case SyncStatus.syncFailed:
        return 'Sync Error (Retries queued)';
    }
  }

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }
}
