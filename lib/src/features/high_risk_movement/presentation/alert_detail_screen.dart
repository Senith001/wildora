import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_shell_tab_controller.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/widgets/app_shell_bottom_nav.dart';
import '../../../data/models/alert.dart';
import '../application/animal_monitoring_controller.dart';
import 'widgets/alert_location_map.dart';

/// Alert Detail Screen displaying high-risk movement alert information.
///
/// Features per wireframe:
/// - Animal name and status
/// - Detected time and location label
/// - GPS status indicator
/// - Zone map placeholder showing zone circle and animal pin
/// - Response section with atomic claim/resolve controls
/// - Real-time updates via StreamBuilder
class AlertDetailScreen extends StatefulWidget {
  final String alertId;
  final AnimalMonitoringController controller;

  const AlertDetailScreen({
    super.key,
    required this.alertId,
    required this.controller,
  });

  @override
  State<AlertDetailScreen> createState() => _AlertDetailScreenState();
}

class _AlertDetailScreenState extends State<AlertDetailScreen> {
  static const String _demoOfficerId = 'demo-user'; // Demo user ID

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alert Details')),
      bottomNavigationBar: AppShellBottomNav(
        selectedIndex: 2,
        onDestinationSelected: (i) {
          // Return to the shell, then select the tapped tab.
          Navigator.of(context).popUntil((r) => r.isFirst);
          AppShellTabController.go(i);
        },
      ),
      body: StreamBuilder<Alert?>(
        stream: widget.controller.alertRepository.watchById(widget.alertId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          final alert = snapshot.data;
          if (alert == null) {
            return _buildErrorState('Alert not found');
          }

          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Alert information section
                  _buildAlertInfoSection(alert),

                  // Zone map placeholder
                  _buildMapSection(alert),

                  // Response section
                  _buildResponseSection(alert),

                  // Bottom spacing
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Build error state widget
  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error Loading Alert',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }

  /// Build alert information section
  Widget _buildAlertInfoSection(Alert alert) {
    final alertColors = Theme.of(context).extension<AlertColors>()!;

    final isResolved = alert.responseStatus == 'resolved';
    final statusLineText = isResolved
        ? 'Resolved'
        : 'In High-Risk Zone';
    final statusLineColor = isResolved
        ? Theme.of(context).colorScheme.secondary
        : alertColors.critical;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Animal info with circular avatar
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Theme.of(context).colorScheme.primary
                      .withOpacity(0.1),
                  child: Icon(
                    Icons.pets,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Animal: ${alert.animalName}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Status: $statusLineText',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: statusLineColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Info rows in a card-style layout
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerHighest
                  .withOpacity(0.3),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _buildInfoRowWithChip(
                      Icons.schedule,
                      'Detected',
                      _formatTimestamp(alert.timestamp.toDate()),
                    ),
                    Divider(
                      height: 24,
                      color: Theme.of(context).colorScheme.outline
                          .withOpacity(0.5),
                    ),
                    _buildInfoRowWithChip(
                      Icons.location_on,
                      'Location',
                      alert.locationLabel ?? 'Unknown Zone',
                    ),
                    Divider(
                      height: 24,
                      color: Theme.of(context).colorScheme.outline
                          .withOpacity(0.5),
                    ),
                    _buildInfoRowWithChip(
                      Icons.gps_fixed,
                      'GPS Status',
                      isResolved ? 'Incident recorded' : 'Active',
                      trailing: const Icon(Icons.chevron_right, size: 20),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build info row with circular icon chip, label and value
  Widget _buildInfoRowWithChip(
    IconData icon,
    String label,
    String value, {
    Widget? trailing,
  }) {
    return Row(
      children: [
        // Leading circular icon chip
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        // Label and value
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        // Optional trailing widget
        if (trailing != null) ...[const SizedBox(width: 8), trailing],
      ],
    );
  }

  /// Build map section with zone and View on Map button
  Widget _buildMapSection(Alert alert) {
    final isResolved = alert.responseStatus == 'resolved';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Incident Location',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (isResolved) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondary
                        .withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Resolved',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Recorded incident location',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          AlertLocationMap(
            animalLocation: alert.location,
            zoneRadiusMeters: 500,
            locationLabel: alert.locationLabel ?? 'High-Risk Zone',
            isResolved: isResolved,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const Key('viewOnMapButton'),
              onPressed: () => _launchGoogleMaps(alert),
              icon: const Icon(Icons.map),
              label: const Text('View on Map'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Theme.of(context).colorScheme.primary,
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build response section with unified status button
  Widget _buildResponseSection(Alert alert) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Response Status',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Current response status
            _buildResponseStatus(alert),

            // Resolution summary (only for resolved alerts with reliable data)
            _buildResolutionSummary(alert),
            const SizedBox(height: 16),

            // Unified status button
            _buildUnifiedStatusButton(alert),
          ],
        ),
      ),
    );
  }

  /// Build response status display
  Widget _buildResponseStatus(Alert alert) {
    final alertColors = Theme.of(context).extension<AlertColors>()!;

    String statusText;
    Color statusColor;
    IconData statusIcon;

    switch (alert.responseStatus) {
      case 'unclaimed':
        statusText = 'No one responding';
        statusColor = alertColors.critical;
        statusIcon = Icons.error_outline;
        break;
      case 'responding':
        final isCurrentUser = alert.respondingOfficerId == _demoOfficerId;
        // Another officer is responding: the name is already shown on the
        // disabled button (otherOfficerButton), so suppress the duplicate
        // status line above it.
        if (!isCurrentUser) {
          return const SizedBox.shrink();
        }
        statusText = 'You are responding';
        statusColor = Theme.of(context).colorScheme.tertiary;
        statusIcon = Icons.directions_run;
        break;
      case 'resolved':
        statusText = 'Situation resolved';
        statusColor = Theme.of(context).colorScheme.secondary;
        statusIcon = Icons.check_circle;
        break;
      default:
        statusText = 'Unknown status';
        statusColor = Theme.of(context).colorScheme.onSurface;
        statusIcon = Icons.help_outline;
    }

    return Row(
      children: [
        Icon(statusIcon, color: statusColor, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            statusText,
            key: const Key('alertStatusText'),
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: statusColor, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  /// Build resolution summary shown only for resolved alerts with reliable data.
  ///
  /// Omits any line whose underlying data is null (e.g. legacy alerts without
  /// resolvedAt, or alerts with no responding officer recorded). Never
  /// fabricates values.
  Widget _buildResolutionSummary(Alert alert) {
    if (alert.responseStatus != 'resolved') {
      return const SizedBox.shrink();
    }

    final officerName = alert.respondingOfficerName;
    final resolvedAt = alert.resolvedAt;

    // Nothing reliable to show.
    if (officerName == null && resolvedAt == null) {
      return const SizedBox.shrink();
    }

    final mutedColor = Theme.of(context).colorScheme.secondary;

    final summaryRows = <Widget>[];
    if (officerName != null) {
      summaryRows.add(
        _buildInfoRowWithChip(
          Icons.person,
          'Responding ranger',
          officerName,
        ),
      );
    }
    if (resolvedAt != null) {
      if (summaryRows.isNotEmpty) {
        summaryRows.add(
          Divider(
            height: 24,
            color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
          ),
        );
      }
      summaryRows.add(
        _buildInfoRowWithChip(
          Icons.check_circle,
          'Resolved',
          _formatTimestamp(resolvedAt.toDate()),
        ),
      );
    }

    return Padding(
      key: const Key('resolutionSummary'),
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        elevation: 0,
        color: mutedColor.withOpacity(0.08),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Resolution Summary',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: mutedColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...summaryRows,
            ],
          ),
        ),
      ),
    );
  }




  /// Launch Google Maps at the animal's exact coordinates
  Future<void> _launchGoogleMaps(Alert alert) async {
    final lat = alert.location.latitude;
    final lng = alert.location.longitude;
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Maps')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps')),
      );
    }
  }

  /// Build unified status button based on alert response status
  Widget _buildUnifiedStatusButton(Alert alert) {
    switch (alert.responseStatus) {
      case 'unclaimed':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            key: const Key('unifiedStatusButton'),
            onPressed: () => _claimResponse(alert),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Theme.of(context).colorScheme.primary,
              side: BorderSide(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            child: const Text('Accepted'),
          ),
        );

      case 'responding':
        final isCurrentUser = alert.respondingOfficerId == _demoOfficerId;

        if (isCurrentUser) {
          return SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const Key('unifiedStatusButton'),
              onPressed: () => _resolveResponse(alert),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFBC02D),
                foregroundColor: Colors.black,
              ),
              child: const Text('Responding'),
            ),
          );
        } else {
          return SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const Key('otherOfficerButton'),
              onPressed: null,
              child: Text('${alert.respondingOfficerName ?? 'Officer'} is responding'),
            ),
          );
        }

      case 'resolved':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            key: const Key('unifiedStatusButton'),
            onPressed: null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Resolved'),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  /// Claim response to the alert (atomic operation)
  Future<void> _claimResponse(Alert alert) async {
    try {
      await widget.controller.alertRepository.claimResponse(
        alert.alertId,
        _demoOfficerId,
        'Demo User', // Demo officer name
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Response claimed successfully'),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to claim response: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Resolve the alert response
  Future<void> _resolveResponse(Alert alert) async {
    try {
      await widget.controller.alertRepository.resolveResponse(alert.alertId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Alert marked as resolved'),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resolve alert: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }



  /// Format timestamp for display
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes} min ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours} hr ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}
