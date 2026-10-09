import 'package:flutter/material.dart';

import '../data/patrol_models.dart';

/// A small coloured badge for displaying status text.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Displays a detail row with icon, label, and value.
class DetailRow extends StatelessWidget {
  const DetailRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
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
      message: isOnline ? 'Online' : 'Offline',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: (isOnline ? Colors.green : Colors.red).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isOnline ? Icons.wifi : Icons.wifi_off,
              size: 16,
              color: isOnline ? Colors.green.shade300 : Colors.red.shade300,
            ),
            const SizedBox(width: 4),
            Text(
              isOnline ? 'Online' : 'Offline',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isOnline ? Colors.green.shade100 : Colors.red.shade100,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// GPS status badge for the app bar.
class GpsStatusBadge extends StatelessWidget {
  const GpsStatusBadge({super.key, required this.available, this.lastFix});

  final bool available;
  final DateTime? lastFix;

  @override
  Widget build(BuildContext context) {
    final String tooltip;
    if (!available) {
      tooltip = 'GPS unavailable';
    } else if (lastFix != null) {
      final ago = DateTime.now().difference(lastFix!);
      if (ago.inSeconds < 60) {
        tooltip = 'GPS fix ${ago.inSeconds}s ago';
      } else {
        tooltip = 'GPS fix ${ago.inMinutes}m ago';
      }
    } else {
      tooltip = 'GPS available';
    }

    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: (available ? Colors.green : Colors.orange).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          available ? Icons.gps_fixed : Icons.gps_off,
          size: 16,
          color: available ? Colors.green.shade300 : Colors.orange.shade300,
        ),
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
    switch (status) {
      case SyncStatus.pendingSync:
        icon = Icons.cloud_upload;
        color = Colors.blue;
      case SyncStatus.synchronized:
        icon = Icons.cloud_done;
        color = const Color(0xFF2E7D32);
      case SyncStatus.syncFailed:
        icon = Icons.sync_problem;
        color = Colors.red;
    }

    final String label;
    switch (status) {
      case SyncStatus.pendingSync:
        label = 'Pending';
      case SyncStatus.synchronized:
        label = 'Synced';
      case SyncStatus.syncFailed:
        label = 'Failed';
    }

    if (compact) {
      return Tooltip(
        message: 'Sync: $label',
        child: Icon(icon, size: 18, color: color.withValues(alpha: 0.9)),
      );
    }

    return Icon(icon, size: 22, color: color);
  }
}
