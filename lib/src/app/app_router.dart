import 'package:flutter/material.dart';

import 'main_navigation_screen.dart';
import '../features/wildlife-incident/wildlife_incident_demo.dart';
import '../features/high_risk_movement/application/animal_monitoring_controller.dart';
import '../features/high_risk_movement/application/high_risk_zone_detection_service.dart';
import '../features/high_risk_movement/presentation/monitoring_dashboard_screen.dart';
import '../features/high_risk_movement/presentation/alert_detail_screen.dart';
import '../features/manage_patrols/application/patrol_controller.dart';
import '../features/manage_patrols/data/patrol_local_store.dart';
import '../features/manage_patrols/data/patrol_location_service.dart';
import '../features/manage_patrols/data/patrol_sync_service.dart';
import '../features/manage_patrols/presentation/assign_patrol_screen.dart';
import '../features/manage_patrols/presentation/assigned_patrol_screen.dart';
import '../features/manage_patrols/presentation/manager_patrol_review_screen.dart';
import '../features/manage_patrols/presentation/ranger_patrol_history_screen.dart';
import 'theme/theme_controller.dart';
import '../data/repositories/animal_repository.dart';
import '../data/repositories/alert_repository.dart';
import '../data/repositories/high_risk_zone_repository.dart';
import '../data/repositories/officer_repository.dart';
import '../data/repositories/duty_roster_repository.dart';
import '../data/repositories/alert_recipient_repository.dart';
import '../features/conflict_reporting/conflict_reporting.dart';
import '../features/conflict_reporting/presentation/clo_access_screen.dart';
import '../features/conflict_reporting/data/firebase_conflict_report_remote.dart';
import '../features/conflict_reporting/data/local_store_factory.dart';
import '../features/conflict_reporting/data/private_conflict_photo_remote.dart';
import '../features/conflict_reporting/domain/conflict_report_ports.dart';
import '../features/conflict_reporting/presentation/conflict_photo_scope.dart';
import '../features/conflict_reporting/presentation/conflict_theme.dart';

/// Route table for Wildora app navigation with dependency injection.
///
/// Constructs screens with proper controller and repository dependencies.
/// Provides Phase G high-risk movement monitoring and alert detail screens.
class AppRouter {
  static const String home = '/';
  static const String monitoring = '/monitoring';
  static const String alert = '/alert';
  static const String patrol = '/patrol';
  static const String patrolAssign = '/patrol/assign';
  static const String patrolManagerReview = '/patrol/manager-review';
  static const String patrolHistory = '/patrol/history';
  static const String wildlifeIncident = '/wildlife-incident';

  final AnimalMonitoringController _monitoringController;
  final ThemeController _themeController;
  final ConflictReportRepository conflictRepository;
  PatrolController? _patrolController;
  final ConflictPhotoRemote? _conflictPhotos;

  AppRouter({
    required AnimalMonitoringController monitoringController,
    required ThemeController themeController,
    ConflictReportRepository? conflictRepository,
    PatrolController? patrolController,
    ConflictPhotoRemote? conflictPhotos,
  }) : _monitoringController = monitoringController,
       _themeController = themeController,
       _patrolController = patrolController,
       _conflictPhotos = conflictPhotos ?? ConflictPhotoConfiguration.create(),
       conflictRepository =
           conflictRepository ??
           ConflictReportRepository(
             store: createConflictReportStore(),
             remote: FirebaseConflictReportRemote(
               uploadPhotos: ConflictPhotoConfiguration.enabled,
               photoRemote:
                   conflictPhotos ?? ConflictPhotoConfiguration.create(),
             ),
           );

  Widget _withConflictPhotos(Widget child) => ConflictFeatureTheme(
    child: ConflictPhotoScope(downloader: _conflictPhotos, child: child),
  );

  PatrolController _getOrCreatePatrolController() {
    if (_patrolController != null) return _patrolController!;
    final localStore = HivePatrolLocalStore();
    final locationService = PatrolLocationService();
    final syncService = PatrolSyncService(localStore: localStore);
    return _patrolController = PatrolController(
      localStore: localStore,
      locationService: locationService,
      syncService: syncService,
    );
  }

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
          builder: (_) => MainNavigationScreen(
            monitoringController: _monitoringController,
            themeController: _themeController,
          ),
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

      case patrol:
        return MaterialPageRoute(
          builder: (_) => AssignedPatrolScreen(
            controller: _getOrCreatePatrolController(),
          ),
          settings: settings,
        );
      case patrolAssign:
        return MaterialPageRoute(
          builder: (_) => AssignPatrolScreen(
            controller: _getOrCreatePatrolController(),
          ),
          settings: settings,
        );
      case patrolManagerReview:
        return MaterialPageRoute(
          builder: (_) => ManagerPatrolReviewScreen(
            controller: _getOrCreatePatrolController(),
          ),
          settings: settings,
        );
      case patrolHistory:
        return MaterialPageRoute(
          builder: (_) => RangerPatrolHistoryScreen(
            controller: _getOrCreatePatrolController(),
          ),
          settings: settings,
        );
      case '/conflict':
        return MaterialPageRoute(
          builder: (_) => _withConflictPhotos(
            ConflictReportingHome(repository: conflictRepository),
          ),
          settings: settings,
        );
      case '/conflict/report':
        return MaterialPageRoute(
          builder: (_) => _withConflictPhotos(
            ConflictReportFormScreen(repository: conflictRepository),
          ),
          settings: settings,
        );
      case '/conflict/reports':
        return MaterialPageRoute(
          builder: (_) => _withConflictPhotos(
            MyConflictReportsScreen(repository: conflictRepository),
          ),
          settings: settings,
        );
      case '/conflict/confirmation':
        return MaterialPageRoute(
          builder: (_) => _withConflictPhotos(
            ConflictConfirmationScreen(
              report: settings.arguments! as ConflictReport,
              repository: conflictRepository,
            ),
          ),
          settings: settings,
        );
      case '/conflict/details':
        return MaterialPageRoute(
          builder: (_) => _withConflictPhotos(
            ConflictDetailsScreen(
              report: settings.arguments! as ConflictReport,
              repository: conflictRepository,
            ),
          ),
          settings: settings,
        );
      case '/conflict/clo':
        return MaterialPageRoute(
          builder: (_) => _withConflictPhotos(
            CloAccessScreen(
              repository: conflictRepository,
              child: CloDashboardScreen(repository: conflictRepository),
            ),
          ),
          settings: settings,
        );
      case '/conflict/clo/review':
        return MaterialPageRoute(
          builder: (_) => _withConflictPhotos(
            CloAccessScreen(
              repository: conflictRepository,
              child: CloReviewScreen(
                report: settings.arguments! as ConflictReport,
                repository: conflictRepository,
              ),
            ),
          ),
          settings: settings,
        );

      default:
        // Fallback to home for unknown routes
        return MaterialPageRoute(
          builder: (_) => MainNavigationScreen(
            monitoringController: _monitoringController,
            themeController: _themeController,
          ),
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
      conflictRepository: ConflictReportRepository(
        store: createConflictReportStore(),
        remote: FirebaseConflictReportRemote(
          uploadPhotos: ConflictPhotoConfiguration.enabled,
          photoRemote: ConflictPhotoConfiguration.create(),
        ),
      ),
    );
  }
}
