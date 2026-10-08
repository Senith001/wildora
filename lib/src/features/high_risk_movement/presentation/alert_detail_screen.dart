import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../data/models/alert.dart';
import '../application/animal_monitoring_controller.dart';
import 'widgets/alert_banner.dart';
import 'widgets/zone_map_placeholder.dart';

/// Alert Detail Screen displaying high-risk movement alert information.
///
/// Features per wireframe:
/// - Red critical alert banner
/// - Animal name and status
/// - Detected time and location label
/// - GPS status indicator
/// - Zone map placeholder showing zone circle and animal pin
/// - Response section with atomic claim/resolve controls
/// - Acknowledge action
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
      appBar: AppBar(
        title: const Text('Alert Details'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
                  // Critical alert banner
                  const AlertBanner(
                    title: 'HIGH-RISK MOVEMENT DETECTED',
                    subtitle: 'Immediate attention required',
                  ),

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

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Animal name and status
          Row(
            children: [
              Icon(Icons.pets, color: alertColors.critical, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Animal: ${alert.animalName}',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Status: Entered High-Risk Zone',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: alertColors.critical,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Detection time and location
          _buildInfoRow(
            Icons.access_time,
            'Detected',
            _formatTimestamp(alert.timestamp.toDate()),
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            Icons.location_on,
            'Location',
            alert.locationLabel ?? 'Unknown Zone',
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            Icons.gps_fixed,
            'GPS Status',
            'Active',
            valueColor: Theme.of(context).colorScheme.secondary,
          ),
        ],
      ),
    );
  }

  /// Build info row with icon, label and value
  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: valueColor ?? Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// Build map section with zone placeholder
  Widget _buildMapSection(Alert alert) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Location Map',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            width: double.infinity,
            child: ZoneMapPlaceholder(
              zoneCenter: alert.location,
              animalLocation: alert.location,
              zoneRadiusMeters: 500, // Default zone radius
              locationLabel: alert.locationLabel ?? 'High-Risk Zone',
            ),
          ),
        ],
      ),
    );
  }

  /// Build response section with claim/resolve controls
  Widget _buildResponseSection(Alert alert) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Response Status',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Current response status
          _buildResponseStatus(alert),
          const SizedBox(height: 16),

          // Action buttons
          _buildActionButtons(alert),
          const SizedBox(height: 12),

          // Acknowledge button
          _buildAcknowledgeButton(alert),
        ],
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
        statusText = isCurrentUser
            ? 'You are responding'
            : '${alert.respondingOfficerName ?? "An officer"} is responding';
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

  /// Build action buttons based on current response status
  Widget _buildActionButtons(Alert alert) {
    final alertColors = Theme.of(context).extension<AlertColors>()!;

    switch (alert.responseStatus) {
      case 'unclaimed':
        // Show "I'm responding" button
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            key: const Key('respondButton'),
            onPressed: () => _claimResponse(alert),
            icon: const Icon(Icons.directions_run),
            label: const Text("I'm responding / Heading there"),
            style: ElevatedButton.styleFrom(
              backgroundColor: alertColors.critical,
              foregroundColor: alertColors.onCritical,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        );

      case 'responding':
        final isCurrentUser = alert.respondingOfficerId == _demoOfficerId;

        if (isCurrentUser) {
          // Current user is responding - show resolve button
          return SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _resolveResponse(alert),
              icon: const Icon(Icons.check),
              label: const Text('Mark as Resolved'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Theme.of(context).colorScheme.onSecondary,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          );
        } else {
          // Another officer is responding - show disabled button
          return SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const Key('otherOfficerButton'),
              onPressed: null,
              icon: const Icon(Icons.person),
              label: Text('${alert.respondingOfficerName} is responding'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          );
        }

      case 'resolved':
        // Show resolved status - no action needed
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).colorScheme.secondary),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Situation Resolved',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  /// Build acknowledge button
  Widget _buildAcknowledgeButton(Alert alert) {
    final alertColors = Theme.of(context).extension<AlertColors>()!;

    if (alert.status == 'acknowledged') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: alertColors.signal.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: alertColors.signal),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.visibility, color: alertColors.signal),
            const SizedBox(width: 8),
            Text(
              'Alert Acknowledged',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: alertColors.signal,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _acknowledgeAlert(alert),
        icon: const Icon(Icons.visibility),
        label: const Text('Acknowledge Alert'),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: alertColors.signal),
          foregroundColor: alertColors.signal,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
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

  /// Acknowledge the alert
  Future<void> _acknowledgeAlert(Alert alert) async {
    try {
      await widget.controller.alertRepository.acknowledge(alert.alertId);

      if (mounted) {
        final alertColors = Theme.of(context).extension<AlertColors>()!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Alert acknowledged'),
            backgroundColor: alertColors.signal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to acknowledge alert: $e'),
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
