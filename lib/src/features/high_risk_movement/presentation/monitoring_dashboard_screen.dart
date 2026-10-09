import 'package:flutter/material.dart';

import '../../../app/theme/theme_controller.dart';
import '../../../data/models/alert.dart';
import '../application/animal_monitoring_controller.dart';
import 'widgets/alert_list_tile.dart';
import 'widgets/simulate_location_sheet.dart';

/// Monitoring Dashboard Screen showing live alerts and development controls.
///
/// Features:
/// - Live StreamBuilder over active alerts
/// - Theme toggle (light/dark/system) in AppBar
/// - Simulate location update control (FAB)
/// - Alert list with response status badges
/// - Navigation to alert detail screen
class MonitoringDashboardScreen extends StatefulWidget {
  final AnimalMonitoringController controller;
  final ThemeController themeController;

  const MonitoringDashboardScreen({
    super.key,
    required this.controller,
    required this.themeController,
  });

  @override
  State<MonitoringDashboardScreen> createState() =>
      _MonitoringDashboardScreenState();
}

class _MonitoringDashboardScreenState extends State<MonitoringDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoring Dashboard'),
        actions: [
          // Theme toggle button
          PopupMenuButton<ThemeMode>(
            icon: Icon(
              _getThemeIcon(widget.themeController.themeMode),
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            onSelected: (ThemeMode mode) {
              widget.themeController.setThemeMode(mode);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: ThemeMode.system,
                child: Row(
                  children: [
                    Icon(Icons.brightness_auto),
                    SizedBox(width: 8),
                    Text('System'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: ThemeMode.light,
                child: Row(
                  children: [
                    Icon(Icons.light_mode),
                    SizedBox(width: 8),
                    Text('Light'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: ThemeMode.dark,
                child: Row(
                  children: [
                    Icon(Icons.dark_mode),
                    SizedBox(width: 8),
                    Text('Dark'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    Icons.eco,
                    size: 40,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'High-Risk Movement Monitoring',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Live alert tracking and response coordination',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Alerts list
            Expanded(
              child: StreamBuilder<List<Alert>>(
                stream: widget.controller.alertRepository.watchActiveAlerts(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
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
                            'Error loading alerts',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            snapshot.error.toString(),
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  final alerts = snapshot.data ?? [];

                  if (alerts.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 64,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No Active Alerts',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'All wildlife is safely outside high-risk zones',
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: alerts.length,
                    itemBuilder: (context, index) {
                      final alert = alerts[index];
                      return AlertListTile(
                        alert: alert,
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/alert',
                            arguments: alert.alertId,
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSimulateLocationSheet(context),
        icon: const Icon(Icons.developer_mode),
        label: const Text('Simulate'),
      ),
    );
  }

  /// Shows the simulate location update bottom sheet
  void _showSimulateLocationSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          SimulateLocationSheet(controller: widget.controller),
    );
  }

  /// Get appropriate icon for current theme mode
  IconData _getThemeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
      case ThemeMode.system:
        return Icons.brightness_auto;
    }
  }
}
