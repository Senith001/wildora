import 'package:flutter/material.dart';

import '../data/patrol_models.dart';
import 'patrol_theme.dart';

/// A small coloured badge for displaying status text with high contrast.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: PatrolTheme.radiusFull,
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Displays a detail row with icon, label, and value with clean typography.
class DetailRow extends StatelessWidget {
  const DetailRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.badge,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: PatrolTheme.forestSurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: PatrolTheme.forestPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: PatrolTheme.charcoalMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (badge != null) ...[
            badge!,
            const SizedBox(width: 8),
          ],
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: PatrolTheme.charcoal,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Connectivity status badge for the app bar.
class ConnectivityBadge extends StatelessWidget {
  const ConnectivityBadge({super.key, required this.isOnline});

  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isOnline
          ? 'Connected to Wildora Network'
          : 'Operating in Offline Mode (Local Storage)',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: (isOnline ? PatrolTheme.success : PatrolTheme.error)
              .withValues(alpha: 0.16),
          borderRadius: PatrolTheme.radiusFull,
          border: Border.all(
            color: (isOnline ? PatrolTheme.success : PatrolTheme.error)
                .withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isOnline ? Icons.wifi : Icons.wifi_off,
              size: 14,
              color: isOnline ? PatrolTheme.forestPrimary : PatrolTheme.error,
            ),
            const SizedBox(width: 5),
            Text(
              isOnline ? 'Online' : 'Offline',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color: isOnline ? PatrolTheme.forestDeep : PatrolTheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// GPS status badge for the app bar with granular signal state and accuracy indication.
class GpsStatusBadge extends StatelessWidget {
  const GpsStatusBadge({
    super.key,
    required this.available,
    this.lastFix,
    this.status,
    this.accuracy,
  });

  final bool available;
  final DateTime? lastFix;
  final GpsSignalStatus? status;
  final double? accuracy;

  @override
  Widget build(BuildContext context) {
    String tooltip;
    Color color = available ? PatrolTheme.forestPrimary : PatrolTheme.amber;
    String label = 'GPS';

    if (status != null) {
      switch (status!) {
        case GpsSignalStatus.locating:
          tooltip = 'Acquiring GPS constellation fixes…';
          color = PatrolTheme.infoBlue;
          label = 'Locating';
        case GpsSignalStatus.available:
          tooltip = 'GPS Lock Active';
          if (accuracy != null && accuracy!.isFinite) {
            tooltip += ' (±${accuracy!.toStringAsFixed(1)}m)';
          }
          if (lastFix != null) {
            final ago = DateTime.now().difference(lastFix!);
            tooltip += ' • ${ago.inSeconds}s ago';
          }
          color = PatrolTheme.forestPrimary;
          label = accuracy != null ? '±${accuracy!.toStringAsFixed(0)}m' : 'GPS Fix';
        case GpsSignalStatus.stale:
          tooltip = 'Stale GPS fix (>30s without update)';
          color = PatrolTheme.amber;
          label = 'Stale GPS';
        case GpsSignalStatus.denied:
          tooltip = 'Location permission denied by user';
          color = PatrolTheme.error;
          label = 'Denied';
        case GpsSignalStatus.permanentlyDenied:
          tooltip = 'Location permission permanently blocked';
          color = PatrolTheme.error;
          label = 'Blocked';
        case GpsSignalStatus.servicesDisabled:
          tooltip = 'Device location services turned off';
          color = PatrolTheme.error;
          label = 'Disabled';
        case GpsSignalStatus.providerError:
          tooltip = 'GPS hardware / provider error';
          color = PatrolTheme.error;
          label = 'Error';
      }
    } else {
      if (!available) {
        tooltip = 'GPS unavailable';
        color = PatrolTheme.amber;
      } else if (lastFix != null) {
        final ago = DateTime.now().difference(lastFix!);
        tooltip = 'GPS fix ${ago.inSeconds}s ago';
      } else {
        tooltip = 'GPS available';
      }
    }

    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: PatrolTheme.radiusFull,
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              available ? Icons.gps_fixed : Icons.gps_off,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A prominent warning banner when development simulation mode is active.
class SimulationWarningBanner extends StatelessWidget {
  const SimulationWarningBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        border: Border.all(color: const Color(0xFFF59E0B)),
        borderRadius: PatrolTheme.radiusSm,
      ),
      child: const Row(
        children: [
          Icon(Icons.developer_mode, color: Color(0xFFB45309), size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'DEV SIMULATION ACTIVE — Injected coordinates. Simulated data is blocked from production sync.',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sync status icon widget.
class SyncStatusIcon extends StatelessWidget {
  const SyncStatusIcon({
    super.key,
    required this.status,
    this.compact = false,
  });

  final SyncStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;
    final String label;

    switch (status) {
      case SyncStatus.pendingSync:
        icon = Icons.cloud_upload;
        color = PatrolTheme.infoBlue;
        label = 'Pending';
      case SyncStatus.synchronized:
        icon = Icons.cloud_done;
        color = PatrolTheme.success;
        label = 'Synced';
      case SyncStatus.syncFailed:
        icon = Icons.sync_problem;
        color = PatrolTheme.error;
        label = 'Failed';
    }

    if (compact) {
      return Tooltip(
        message: 'Sync: $label',
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Responsive wrapper that constrains maxWidth on larger screens and centers content.
class ResponsiveContentWrapper extends StatelessWidget {
  const ResponsiveContentWrapper({
    super.key,
    required this.child,
    this.maxWidth = PatrolTheme.maxContentWidth,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

/// Shared field operational card with header, subtle elevation and border.
class OperationalCard extends StatelessWidget {
  const OperationalCard({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.trailing,
    this.backgroundColor,
    this.borderColor,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final String? title;
  final IconData? icon;
  final Widget? trailing;
  final Color? backgroundColor;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: PatrolTheme.cardDecoration(
        backgroundColor: backgroundColor,
        borderColor: borderColor,
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: PatrolTheme.forestPrimary),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title!,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: PatrolTheme.charcoal,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: PatrolTheme.borderLight),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

// ─── Waypoint List Panel ─────────────────────────────────────────────────────

/// Scrollable list of waypoints for display on active patrol and completed screens.
///
/// Each row is tappable to open a detail bottom sheet.
/// [isRanger] controls whether offline-only sync labels are shown.
class WaypointListPanel extends StatelessWidget {
  const WaypointListPanel({
    super.key,
    required this.waypoints,
    this.isRanger = true,
    this.emptyLabel = 'No waypoints recorded yet.',
  });

  final List<Waypoint> waypoints;
  final bool isRanger;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (waypoints.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            emptyLabel,
            style: const TextStyle(
              color: PatrolTheme.charcoalMuted,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: waypoints.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, color: PatrolTheme.borderLight),
      itemBuilder: (context, idx) {
        final wp = waypoints[idx];
        return _WaypointListTile(
          waypoint: wp,
          index: idx + 1,
          isRanger: isRanger,
          onTap: () => showWaypointDetail(context, wp, isRanger: isRanger),
        );
      },
    );
  }
}

class _WaypointListTile extends StatelessWidget {
  const _WaypointListTile({
    required this.waypoint,
    required this.index,
    required this.isRanger,
    required this.onTap,
  });

  final Waypoint waypoint;
  final int index;
  final bool isRanger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSynced = waypoint.isSynchronized;
    final syncColor = isSynced ? PatrolTheme.success : PatrolTheme.amberDark;

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: PatrolTheme.forestSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: PatrolTheme.forestBorder),
        ),
        child: Icon(
          waypointTypeIcon(waypoint.type),
          size: 18,
          color: PatrolTheme.forestPrimary,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              '#$index \u2014 ${waypoint.type.label}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: PatrolTheme.charcoal,
              ),
            ),
          ),
          if (isRanger)
            StatusBadge(
              label: isSynced ? 'Synced' : 'Local',
              color: syncColor,
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(
            '${waypoint.latitude.toStringAsFixed(5)}, '
            '${waypoint.longitude.toStringAsFixed(5)}',
            style: const TextStyle(
              fontSize: 11,
              color: PatrolTheme.charcoalMuted,
              fontFamily: 'monospace',
            ),
          ),
          if (waypoint.note != null && waypoint.note!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                waypoint.note!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: PatrolTheme.charcoalMuted,
                ),
              ),
            ),
        ],
      ),
      trailing: const Icon(
        Icons.chevron_right,
        size: 18,
        color: PatrolTheme.charcoalSubtle,
      ),
      onTap: onTap,
    );
  }
}

/// Open a bottom sheet with full waypoint details.
void showWaypointDetail(
  BuildContext context,
  Waypoint waypoint, {
  bool isRanger = true,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _WaypointDetailSheet(waypoint: waypoint, isRanger: isRanger),
  );
}

class _WaypointDetailSheet extends StatelessWidget {
  const _WaypointDetailSheet({
    required this.waypoint,
    required this.isRanger,
  });

  final Waypoint waypoint;
  final bool isRanger;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.60,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (context, scroll) {
        return Container(
          decoration: const BoxDecoration(
            color: PatrolTheme.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: PatrolTheme.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Title row
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: PatrolTheme.forestSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: PatrolTheme.forestBorder),
                      ),
                      child: Icon(
                        waypointTypeIcon(waypoint.type),
                        size: 22,
                        color: PatrolTheme.forestPrimary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            waypoint.type.label,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: PatrolTheme.charcoal,
                            ),
                          ),
                          const Text(
                            'Tap any field to copy',
                            style: TextStyle(
                              fontSize: 11,
                              color: PatrolTheme.charcoalMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          size: 20, color: PatrolTheme.charcoalMuted),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: PatrolTheme.borderLight),
              // Detail list
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.all(18),
                  children: [
                    _SheetDetailRow(
                      icon: Icons.pin_drop_outlined,
                      label: 'Latitude',
                      value: waypoint.latitude.toStringAsFixed(7),
                    ),
                    _SheetDetailRow(
                      icon: Icons.pin_drop_outlined,
                      label: 'Longitude',
                      value: waypoint.longitude.toStringAsFixed(7),
                    ),
                    _SheetDetailRow(
                      icon: waypoint.locationSource == LocationSource.gps
                          ? Icons.gps_fixed
                          : Icons.edit_location_alt_outlined,
                      label: 'Location Source',
                      value: waypoint.locationSource == LocationSource.gps
                          ? 'GPS Hardware Fix'
                          : waypoint.locationSource ==
                                  LocationSource.simulated
                              ? 'Simulated (dev only)'
                              : 'Manual Entry',
                    ),
                    _SheetDetailRow(
                      icon: Icons.access_time,
                      label: 'Captured At',
                      value: waypoint.timestamp
                          .toLocal()
                          .toIso8601String()
                          .replaceAll('T', ' ')
                          .substring(0, 19),
                    ),
                    if (waypoint.note != null && waypoint.note!.isNotEmpty)
                      _SheetDetailRow(
                        icon: Icons.notes,
                        label: 'Field Note',
                        value: waypoint.note!,
                      ),
                    if (waypoint.photoReference != null)
                      _SheetDetailRow(
                        icon: Icons.camera_alt_outlined,
                        label: 'Photo Reference',
                        value: waypoint.photoReference!,
                      ),
                    // Sync label: rangers see local status; managers only see synced data
                    if (isRanger)
                      _SheetDetailRow(
                        icon: waypoint.isSynchronized
                            ? Icons.cloud_done
                            : Icons.cloud_off,
                        label: 'Sync Status',
                        value: waypoint.isSynchronized
                            ? 'Synchronized to server'
                            : 'Saved on device — not yet uploaded',
                        valueColor: waypoint.isSynchronized
                            ? PatrolTheme.success
                            : PatrolTheme.amberDark,
                      ),
                    const SizedBox(height: 8),
                    _SheetDetailRow(
                      icon: Icons.key,
                      label: 'Waypoint ID',
                      value: waypoint.id,
                    ),
                    _SheetDetailRow(
                      icon: Icons.assignment,
                      label: 'Session ID',
                      value: waypoint.sessionId,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SheetDetailRow extends StatelessWidget {
  const _SheetDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: PatrolTheme.forestPrimary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: PatrolTheme.charcoalMuted,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 3),
                SelectableText(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? PatrolTheme.charcoal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Returns the icon for a given [WaypointType].
IconData waypointTypeIcon(WaypointType type) {
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
      return Icons.more_horiz;
  }
}
