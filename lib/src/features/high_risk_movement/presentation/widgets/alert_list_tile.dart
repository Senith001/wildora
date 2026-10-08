import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../data/models/alert.dart';

/// List tile widget for displaying alert summaries in the monitoring dashboard.
///
/// Features:
/// - Animal name and zone/location label
/// - Formatted time display
/// - Response status badge (unclaimed/responding/resolved/acknowledged)
/// - Tap handling for navigation to detail screen
/// - Theme-aware colors and typography
class AlertListTile extends StatelessWidget {
  final Alert alert;
  final VoidCallback? onTap;

  const AlertListTile({super.key, required this.alert, this.onTap});

  @override
  Widget build(BuildContext context) {
    final alertColors = Theme.of(context).extension<AlertColors>()!;
    final timestamp = alert.timestamp.toDate();
    final responseStatus = alert.responseStatus;
    final status = alert.status;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: alertColors.critical.withOpacity(0.1),
          child: Icon(Icons.pets, color: alertColors.critical, size: 20),
        ),
        title: Text(
          alert.animalName,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              alert.locationLabel ?? 'Unknown Location',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(timestamp),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildResponseStatusBadge(context, responseStatus, status),
            const SizedBox(height: 4),
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 16,
            ),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  /// Build response status badge with appropriate color and text
  Widget _buildResponseStatusBadge(
    BuildContext context,
    String responseStatus,
    String alertStatus,
  ) {
    final alertColors = Theme.of(context).extension<AlertColors>()!;

    // Determine badge properties based on status
    String badgeText;
    Color badgeColor;
    Color textColor;

    if (alertStatus == 'acknowledged') {
      badgeText = 'SEEN';
      badgeColor = alertColors.signal;
      textColor = Theme.of(context).colorScheme.onPrimary;
    } else {
      switch (responseStatus) {
        case 'unclaimed':
          badgeText = 'URGENT';
          badgeColor = alertColors.critical;
          textColor = alertColors.onCritical;
          break;
        case 'responding':
          badgeText = 'RESPONDING';
          badgeColor = Theme.of(context).colorScheme.tertiary;
          textColor = Theme.of(context).colorScheme.onTertiary;
          break;
        case 'resolved':
          badgeText = 'RESOLVED';
          badgeColor = Theme.of(context).colorScheme.secondary;
          textColor = Theme.of(context).colorScheme.onSecondary;
          break;
        default:
          badgeText = 'UNKNOWN';
          badgeColor = Theme.of(context).colorScheme.surfaceVariant;
          textColor = Theme.of(context).colorScheme.onSurfaceVariant;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        badgeText,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  /// Parse timestamp from various possible formats
  /// Format timestamp for display in list tile
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}
