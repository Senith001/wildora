import 'package:flutter/material.dart';

import '../../../app/theme/theme_controller.dart';
import '../../../data/models/alert.dart';
import '../application/animal_monitoring_controller.dart';
import 'widgets/alert_list_tile.dart';
import 'widgets/simulate_location_sheet.dart';

/// Monitoring Dashboard Screen showing live alerts and development controls.
///
/// Features:
/// - PickMe-style tab selector (Active / Responding / Resolved)
/// - Live StreamBuilder over all alerts, filtered client-side per tab
/// - Theme toggle (light/dark/system) in AppBar
/// - Simulate location update control (FAB, gated behind dev flag)
/// - Alert list with response status badges
/// - Navigation to alert detail screen
class MonitoringDashboardScreen extends StatefulWidget {
  final AnimalMonitoringController controller;
  final ThemeController themeController;

  /// When true, the screen is embedded inside the app shell and the AppBar
  /// omits the implicit back arrow.
  final bool isEmbedded;

  const MonitoringDashboardScreen({
    super.key,
    required this.controller,
    required this.themeController,
    this.isEmbedded = false,
  });

  @override
  State<MonitoringDashboardScreen> createState() =>
      _MonitoringDashboardScreenState();
}

class _MonitoringDashboardScreenState extends State<MonitoringDashboardScreen> {
  /// Development-only simulate control. Hidden in production.
  static const bool _showSimulateButton = false;

  /// Currently selected tab index.
  int _selectedTabIndex = 0;

  /// Visible tab labels.
  static const List<String> _tabLabels = ['Active', 'Responding', 'Resolved'];

  /// Response-status filter applied per tab (index-aligned with [_tabLabels]).
  static const List<String> _tabFilters = [
    AlertResponseStatus.unclaimed,
    AlertResponseStatus.responding,
    AlertResponseStatus.resolved,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoring Dashboard'),
        automaticallyImplyLeading: !widget.isEmbedded,
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

            // PickMe-style tab selector
            _buildTabSelector(context),

            // Alerts list
            Expanded(
              child: StreamBuilder<List<Alert>>(
                stream: widget.controller.alertRepository.streamAlerts(),
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

                  final allAlerts = snapshot.data ?? [];
                  final filter = _tabFilters[_selectedTabIndex];
                  final alerts = allAlerts
                      .where((a) => a.responseStatus == filter)
                      .toList();

                  if (alerts.isEmpty) {
                    return _buildEmptyState(context);
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
      floatingActionButton: _showSimulateButton
          ? FloatingActionButton.extended(
              onPressed: () => _showSimulateLocationSheet(context),
              icon: const Icon(Icons.developer_mode),
              label: const Text('Simulate'),
            )
          : null,
    );
  }

  /// Build the PickMe-style tab selector row.
  Widget _buildTabSelector(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: List.generate(_tabLabels.length, (index) {
        final isSelected = _selectedTabIndex == index;
        return Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() {
                _selectedTabIndex = index;
              });
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _tabLabels[index],
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
                Container(
                  height: 3,
                  color: isSelected ? colorScheme.primary : Colors.transparent,
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  /// Build the empty-state message for the currently selected tab.
  Widget _buildEmptyState(BuildContext context) {
    String title;
    String message;
    IconData icon;

    switch (_selectedTabIndex) {
      case 0:
        icon = Icons.check_circle_outline;
        title = 'No Active Alerts';
        message = 'All wildlife is safely outside high-risk zones';
        break;
      case 1:
        icon = Icons.directions_run;
        title = 'No Responding Alerts';
        message = 'No alerts are currently being responded to';
        break;
      case 2:
      default:
        icon = Icons.task_alt;
        title = 'No Resolved Alerts';
        message = 'Resolved alerts will appear here';
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
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
