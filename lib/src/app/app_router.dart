import 'package:flutter/material.dart';

import 'main_navigation_screen.dart';
import '../features/wildlife-incident/wildlife_incident_demo.dart';
import '../features/high_risk_movement/application/animal_monitoring_controller.dart';
import '../features/high_risk_movement/application/high_risk_zone_detection_service.dart';
import '../features/high_risk_movement/presentation/monitoring_dashboard_screen.dart';
import '../features/high_risk_movement/presentation/alert_detail_screen.dart';
import 'theme/theme_controller.dart';
import '../data/repositories/animal_repository.dart';
import '../data/repositories/alert_repository.dart';
import '../data/repositories/high_risk_zone_repository.dart';
import '../data/repositories/officer_repository.dart';
import '../data/repositories/duty_roster_repository.dart';
import '../data/repositories/alert_recipient_repository.dart';

/// Route table for Wildora app navigation with dependency injection.
///
/// Constructs screens with proper controller and repository dependencies.
/// Provides Phase G high-risk movement monitoring and alert detail screens.
class AppRouter {
  static const String home = '/';
  static const String monitoring = '/monitoring';
  static const String alert = '/alert';
  static const String wildlifeIncident = '/wildlife-incident';

  final AnimalMonitoringController _monitoringController;
  final ThemeController _themeController;

  AppRouter({
    required AnimalMonitoringController monitoringController,
    required ThemeController themeController,
  }) : _monitoringController = monitoringController,
       _themeController = themeController;

  /// Generate route for named routing with dependency injection.
  ///
  /// Constructs screens with required controllers and repositories.
  /// Unknown routes fall back to home screen.
  Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case wildlifeIncident:
        return MaterialPageRoute(
          builder: (_) => WildlifeIncidentDemo(
            initialTab:
                settings.arguments is int &&
                    (settings.arguments as int) >= 0 &&
                    (settings.arguments as int) <= 2
                ? settings.arguments as int
                : 0,
          ),
          settings: settings,
        );
      case home:
        return MaterialPageRoute(
          builder: (_) => const MainNavigationScreen(),
          settings: settings,
        );

      case monitoring:
        return MaterialPageRoute(
          builder: (_) => MonitoringDashboardScreen(
            controller: _monitoringController,
            themeController: _themeController,
          ),
          settings: settings,
        );

      case alert:
        final alertId = settings.arguments as String?;
        if (alertId == null) {
          // Fallback to monitoring dashboard if no alert ID provided
          return MaterialPageRoute(
            builder: (_) => MonitoringDashboardScreen(
              controller: _monitoringController,
              themeController: _themeController,
            ),
            settings: settings,
          );
        }

        return MaterialPageRoute(
          builder: (_) => AlertDetailScreen(
            alertId: alertId,
            controller: _monitoringController,
          ),
          settings: settings,
        );

      default:
        // Fallback to home for unknown routes
        return MaterialPageRoute(
          builder: (_) => const MainNavigationScreen(),
          settings: settings,
        );
    }
  }

  /// Create AppRouter with properly initialized dependencies.
  ///
  /// Constructs Firestore repository implementations and controllers
  /// with demo configuration. For production, repositories would be
  /// injected from higher level dependency injection container.
  static AppRouter createWithFirestoreDependencies({
    required ThemeController themeController,
  }) {
    // Create Firestore repository implementations
    // Note: In production, these would be injected via DI container
    final animalRepository = FirestoreAnimalRepository();
    final alertRepository = FirestoreAlertRepository();
    final zoneRepository = FirestoreHighRiskZoneRepository();
    final officerRepository = FirestoreOfficerRepository();
    final dutyRosterRepository = FirestoreDutyRosterRepository();
    final alertRecipientRepository = FirestoreAlertRecipientRepository();

    // Create detection service with repositories
    final detectionService = HighRiskZoneDetectionService(
      officerRepository: officerRepository,
      dutyRosterRepository: dutyRosterRepository,
      zoneRepository: zoneRepository,
    );

    // Create monitoring controller with repository dependencies
    final monitoringController = AnimalMonitoringController(
      animalRepository: animalRepository,
      alertRepository: alertRepository,
      alertRecipientRepository: alertRecipientRepository,
      detectionService: detectionService,
      zoneRepository: zoneRepository,
    );

    return AppRouter(
      monitoringController: monitoringController,
      themeController: themeController,
    );
  }
}
