// Monitor Wildlife and Respond to Risk Alerts — Alert UI suite.
//
// Widget tests merging the AlertListTile badge mapping, the
// MonitoringDashboardScreen tab filtering/empty/error/navigation behavior, and
// the AlertDetailScreen response/resolution flows. Reuses the shared in-memory
// fakes and AppTheme.light()/dark(). Independent of the old test folder.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wildora/src/app/theme/app_theme.dart';
import 'package:wildora/src/app/theme/theme_controller.dart';
import 'package:wildora/src/data/models/alert.dart';
import 'package:wildora/src/features/high_risk_movement/application/animal_monitoring_controller.dart';
import 'package:wildora/src/features/high_risk_movement/application/high_risk_zone_detection_service.dart';
import 'package:wildora/src/features/high_risk_movement/presentation/alert_detail_screen.dart';
import 'package:wildora/src/features/high_risk_movement/presentation/monitoring_dashboard_screen.dart';
import 'package:wildora/src/features/high_risk_movement/presentation/widgets/alert_list_tile.dart';

import '../fakes/in_memory_repositories.dart';

void main() {
  // ===========================================================================
  // AlertListTile — riskLevel badge mapping
  // ===========================================================================
  group('AlertListTile badge mapping', () {
    Alert unclaimed({String? riskLevel}) => Alert(
      alertId: 'alert-001',
      type: 'high_risk_movement',
      timestamp: Timestamp.now(),
      status: 'active',
      responseStatus: 'unclaimed',
      animalId: 'elephant-23-id',
      zoneId: 'zone-001',
      location: const AlertLocation(latitude: -1.2921, longitude: 36.8219),
      animalName: 'Elephant-23',
      locationLabel: 'Farmland Border',
      riskLevel: riskLevel,
    );

    Future<void> pumpTile(WidgetTester tester, Alert alert) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: AlertListTile(alert: alert)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('High riskLevel renders the HIGH badge', (tester) async {
      await pumpTile(tester, unclaimed(riskLevel: 'High'));
      expect(find.text('HIGH'), findsOneWidget);
      expect(find.text('URGENT'), findsNothing);
    });

    testWidgets('Medium riskLevel renders the MEDIUM badge', (tester) async {
      await pumpTile(tester, unclaimed(riskLevel: 'Medium'));
      expect(find.text('MEDIUM'), findsOneWidget);
      expect(find.text('URGENT'), findsNothing);
    });

    testWidgets('Low riskLevel renders the LOW badge', (tester) async {
      await pumpTile(tester, unclaimed(riskLevel: 'Low'));
      expect(find.text('LOW'), findsOneWidget);
      expect(find.text('URGENT'), findsNothing);
    });

    testWidgets('null riskLevel falls back to the legacy URGENT badge',
        (tester) async {
      await pumpTile(tester, unclaimed(riskLevel: null));
      expect(find.text('URGENT'), findsOneWidget);
      expect(find.text('HIGH'), findsNothing);
      expect(find.text('MEDIUM'), findsNothing);
      expect(find.text('LOW'), findsNothing);
    });
  });

  // ===========================================================================
  // MonitoringDashboardScreen
  // ===========================================================================
  group('MonitoringDashboardScreen', () {
    late InMemoryAnimalRepository animalRepository;
    late InMemoryAlertRepository alertRepository;
    late InMemoryHighRiskZoneRepository zoneRepository;
    late InMemoryOfficerRepository officerRepository;
    late InMemoryDutyRosterRepository dutyRosterRepository;
    late InMemoryAlertRecipientRepository alertRecipientRepository;
    late InMemoryUserPreferencesRepository preferencesRepository;

    late AnimalMonitoringController controller;
    late ThemeController themeController;

    setUp(() {
      animalRepository = InMemoryAnimalRepository();
      alertRepository = InMemoryAlertRepository();
      zoneRepository = InMemoryHighRiskZoneRepository();
      officerRepository = InMemoryOfficerRepository();
      dutyRosterRepository = InMemoryDutyRosterRepository();
      alertRecipientRepository = InMemoryAlertRecipientRepository();
      preferencesRepository = InMemoryUserPreferencesRepository();

      final detectionService = HighRiskZoneDetectionService(
        officerRepository: officerRepository,
        dutyRosterRepository: dutyRosterRepository,
        zoneRepository: zoneRepository,
      );

      controller = AnimalMonitoringController(
        animalRepository: animalRepository,
        alertRepository: alertRepository,
        alertRecipientRepository: alertRecipientRepository,
        detectionService: detectionService,
        zoneRepository: zoneRepository,
      );

      themeController = ThemeController(preferencesRepository);
    });

    tearDown(() {
      controller.dispose();
      themeController.dispose();
      animalRepository.dispose();
      alertRepository.dispose();
      zoneRepository.dispose();
      officerRepository.dispose();
      dutyRosterRepository.dispose();
      alertRecipientRepository.dispose();
      preferencesRepository.dispose();
    });

    Alert buildAlert({
      required String alertId,
      required String responseStatus,
      required String animalName,
      required String locationLabel,
      Duration age = Duration.zero,
    }) {
      return Alert(
        alertId: alertId,
        type: 'high_risk_movement',
        timestamp: Timestamp.fromDate(DateTime.now().subtract(age)),
        status: 'active',
        responseStatus: responseStatus,
        animalId: '$animalName-id',
        zoneId: 'zone-001',
        location: const AlertLocation(latitude: -1.2921, longitude: 36.8219),
        animalName: animalName,
        locationLabel: locationLabel,
      );
    }

    Future<void> pumpDashboard(
      WidgetTester tester, {
      ThemeMode themeMode = ThemeMode.light,
      Map<String, WidgetBuilder>? routes,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeMode,
          routes: routes ?? const {},
          home: MonitoringDashboardScreen(
            controller: controller,
            themeController: themeController,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows the empty-state message when there are no alerts',
        (tester) async {
      alertRepository.seed([]);
      await pumpDashboard(tester);

      expect(find.text('Monitoring Dashboard'), findsOneWidget);
      expect(find.text('No Active Alerts'), findsOneWidget);
      expect(
        find.text('All wildlife is safely outside high-risk zones'),
        findsOneWidget,
      );
    });

    testWidgets('renders the three tab labels', (tester) async {
      alertRepository.seed([]);
      await pumpDashboard(tester);

      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Responding'), findsOneWidget);
      expect(find.text('Resolved'), findsOneWidget);
    });

    testWidgets('Active tab shows only unclaimed alerts (URGENT, no SEEN)',
        (tester) async {
      alertRepository.seed([
        buildAlert(
          alertId: 'alert-001',
          responseStatus: 'unclaimed',
          animalName: 'Elephant-23',
          locationLabel: 'Farmland Border',
        ),
        buildAlert(
          alertId: 'alert-002',
          responseStatus: 'responding',
          animalName: 'Buffalo-22',
          locationLabel: 'Main Road',
          age: const Duration(hours: 1),
        ),
      ]);
      await pumpDashboard(tester);

      expect(find.text('Elephant-23'), findsOneWidget);
      expect(find.text('Farmland Border'), findsOneWidget);
      expect(find.text('URGENT'), findsOneWidget);
      expect(find.text('SEEN'), findsNothing);
      expect(find.text('Buffalo-22'), findsNothing);
      expect(find.text('No Active Alerts'), findsNothing);
    });

    testWidgets('Responding tab filters to responding alerts', (tester) async {
      alertRepository.seed([
        buildAlert(
          alertId: 'alert-001',
          responseStatus: 'unclaimed',
          animalName: 'Elephant-23',
          locationLabel: 'Farmland Border',
        ),
        buildAlert(
          alertId: 'alert-002',
          responseStatus: 'responding',
          animalName: 'Buffalo-22',
          locationLabel: 'Main Road',
          age: const Duration(hours: 1),
        ),
        buildAlert(
          alertId: 'alert-003',
          responseStatus: 'resolved',
          animalName: 'Zebra-07',
          locationLabel: 'River Crossing',
          age: const Duration(hours: 2),
        ),
      ]);
      await pumpDashboard(tester);

      await tester.tap(find.text('Responding'));
      await tester.pumpAndSettle();

      expect(find.text('Buffalo-22'), findsOneWidget);
      expect(find.text('RESPONDING'), findsOneWidget);
      expect(find.text('SEEN'), findsNothing);
      expect(find.text('Elephant-23'), findsNothing);
      expect(find.text('Zebra-07'), findsNothing);
    });

    testWidgets('Resolved tab filters to resolved alerts', (tester) async {
      alertRepository.seed([
        buildAlert(
          alertId: 'alert-001',
          responseStatus: 'unclaimed',
          animalName: 'Elephant-23',
          locationLabel: 'Farmland Border',
        ),
        buildAlert(
          alertId: 'alert-003',
          responseStatus: 'resolved',
          animalName: 'Zebra-07',
          locationLabel: 'River Crossing',
          age: const Duration(hours: 2),
        ),
      ]);
      await pumpDashboard(tester);

      await tester.tap(find.text('Resolved'));
      await tester.pumpAndSettle();

      expect(find.text('Zebra-07'), findsOneWidget);
      expect(find.text('RESOLVED'), findsOneWidget);
      expect(find.text('SEEN'), findsNothing);
      expect(find.text('Elephant-23'), findsNothing);
    });

    testWidgets('does not show a theme switcher', (tester) async {
      alertRepository.seed([]);
      await pumpDashboard(tester);

      expect(find.byType(PopupMenuButton<ThemeMode>), findsNothing);
      expect(find.byIcon(Icons.brightness_auto), findsNothing);
    });

    testWidgets('simulate FAB is hidden by default', (tester) async {
      alertRepository.seed([]);
      await pumpDashboard(tester);

      expect(find.text('Simulate'), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('handles the error state gracefully', (tester) async {
      alertRepository.setMockError('Firestore connection failed');
      await pumpDashboard(tester);

      expect(find.text('Error loading alerts'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.textContaining('Firestore connection failed'), findsOneWidget);
    });

    testWidgets('renders in dark theme without exceptions', (tester) async {
      alertRepository.seed([]);
      await themeController.setThemeMode(ThemeMode.dark);
      await pumpDashboard(tester, themeMode: ThemeMode.dark);

      expect(find.text('Monitoring Dashboard'), findsOneWidget);
      expect(find.text('No Active Alerts'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping an alert navigates to /alert with its id',
        (tester) async {
      alertRepository.seed([
        buildAlert(
          alertId: 'alert-001',
          responseStatus: 'unclaimed',
          animalName: 'Elephant-23',
          locationLabel: 'Farmland Border',
        ),
      ]);

      var navigated = false;
      String? navigatedId;

      await pumpDashboard(
        tester,
        routes: {
          '/alert': (context) {
            final args = ModalRoute.of(context)!.settings.arguments as String;
            navigated = true;
            navigatedId = args;
            return Scaffold(body: Center(child: Text('Alert Detail for $args')));
          },
        },
      );

      await tester.tap(find.text('Elephant-23'));
      await tester.pumpAndSettle();

      expect(navigated, isTrue);
      expect(navigatedId, equals('alert-001'));
      expect(find.text('Alert Detail for alert-001'), findsOneWidget);
    });
  });

  // ===========================================================================
  // AlertDetailScreen
  // ===========================================================================
  group('AlertDetailScreen', () {
    late InMemoryAnimalRepository animalRepository;
    late InMemoryAlertRepository alertRepository;
    late InMemoryHighRiskZoneRepository zoneRepository;
    late InMemoryOfficerRepository officerRepository;
    late InMemoryDutyRosterRepository dutyRosterRepository;
    late InMemoryAlertRecipientRepository alertRecipientRepository;

    late AnimalMonitoringController controller;

    setUp(() {
      animalRepository = InMemoryAnimalRepository();
      alertRepository = InMemoryAlertRepository();
      zoneRepository = InMemoryHighRiskZoneRepository();
      officerRepository = InMemoryOfficerRepository();
      dutyRosterRepository = InMemoryDutyRosterRepository();
      alertRecipientRepository = InMemoryAlertRecipientRepository();

      final detectionService = HighRiskZoneDetectionService(
        officerRepository: officerRepository,
        dutyRosterRepository: dutyRosterRepository,
        zoneRepository: zoneRepository,
      );

      controller = AnimalMonitoringController(
        animalRepository: animalRepository,
        alertRepository: alertRepository,
        alertRecipientRepository: alertRecipientRepository,
        detectionService: detectionService,
        zoneRepository: zoneRepository,
      );
    });

    tearDown(() {
      controller.dispose();
      animalRepository.dispose();
      alertRepository.dispose();
      zoneRepository.dispose();
      officerRepository.dispose();
      dutyRosterRepository.dispose();
      alertRecipientRepository.dispose();
    });

    Future<void> pumpDetail(
      WidgetTester tester, {
      ThemeData? theme,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme ?? AppTheme.light(),
          home: AlertDetailScreen(alertId: 'alert-001', controller: controller),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('unclaimed alert shows Accepted button and no banner/summary',
        (tester) async {
      alertRepository.setupAlert(
        'alert-001',
        Alert(
          alertId: 'alert-001',
          type: 'high_risk_movement',
          timestamp: Timestamp.now(),
          status: 'active',
          responseStatus: 'unclaimed',
          animalId: 'elephant-23',
          zoneId: 'zone-farmland',
          location: const AlertLocation(latitude: -1.2921, longitude: 36.8219),
          animalName: 'Elephant-23',
          locationLabel: 'Farmland Border',
        ),
      );
      await pumpDetail(tester);

      // Banner is gone.
      expect(find.text('HIGH-RISK MOVEMENT DETECTED'), findsNothing);
      expect(find.byIcon(Icons.warning), findsNothing);

      expect(find.text('Animal: Elephant-23'), findsOneWidget);
      expect(find.text('Status: In High-Risk Zone'), findsOneWidget);
      expect(find.text('Farmland Border'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);

      expect(find.byKey(const Key('alertStatusText')), findsOneWidget);
      expect(find.text('No one responding'), findsOneWidget);
      expect(find.byKey(const Key('unifiedStatusButton')), findsOneWidget);
      expect(find.text('Accepted'), findsOneWidget);

      expect(find.byKey(const Key('resolutionSummary')), findsNothing);
      expect(find.byKey(const Key('viewOnMapButton')), findsOneWidget);
      expect(find.text('Incident Location'), findsOneWidget);
    });

    testWidgets('responding-by-demo-user shows "You are responding" + Responding',
        (tester) async {
      alertRepository.setupAlert(
        'alert-001',
        Alert(
          alertId: 'alert-001',
          type: 'high_risk_movement',
          timestamp: Timestamp.now(),
          status: 'active',
          responseStatus: 'responding',
          respondingOfficerId: 'demo-user',
          respondingOfficerName: 'Demo User',
          respondingAt: Timestamp.now(),
          animalId: 'elephant-23',
          zoneId: 'zone-farmland',
          location: const AlertLocation(latitude: -1.2921, longitude: 36.8219),
          animalName: 'Elephant-23',
          locationLabel: 'Farmland Border',
        ),
      );
      await pumpDetail(tester);

      expect(find.byKey(const Key('alertStatusText')), findsOneWidget);
      expect(find.text('You are responding'), findsOneWidget);
      expect(find.byKey(const Key('unifiedStatusButton')), findsOneWidget);
      expect(find.text('Responding'), findsOneWidget);
      expect(find.byIcon(Icons.directions_run), findsOneWidget);
      expect(find.text('Status: In High-Risk Zone'), findsOneWidget);
      expect(find.text('Incident Location'), findsOneWidget);
      expect(find.byKey(const Key('resolutionSummary')), findsNothing);
    });

    testWidgets('tapping resolve records a resolveResponse call', (tester) async {
      alertRepository.setupAlert(
        'alert-001',
        Alert(
          alertId: 'alert-001',
          type: 'high_risk_movement',
          timestamp: Timestamp.now(),
          status: 'active',
          responseStatus: 'responding',
          respondingOfficerId: 'demo-user',
          respondingOfficerName: 'Demo User',
          respondingAt: Timestamp.now(),
          animalId: 'elephant-23',
          zoneId: 'zone-farmland',
          location: const AlertLocation(latitude: -1.2921, longitude: 36.8219),
          animalName: 'Elephant-23',
          locationLabel: 'Farmland Border',
        ),
      );
      await pumpDetail(tester);

      await tester.scrollUntilVisible(find.text('Responding'), 500.0);
      await tester.tap(find.byKey(const Key('unifiedStatusButton')));
      await tester.pumpAndSettle();

      expect(alertRepository.resolveResponseCalls, hasLength(1));
      expect(alertRepository.resolveResponseCalls.first, equals('alert-001'));
    });

    testWidgets('other-officer responding suppresses status line, name on button',
        (tester) async {
      alertRepository.setupAlert(
        'alert-001',
        Alert(
          alertId: 'alert-001',
          type: 'high_risk_movement',
          timestamp: Timestamp.now(),
          status: 'active',
          responseStatus: 'responding',
          respondingOfficerId: 'ranger-amara',
          respondingOfficerName: 'Ranger Amara',
          respondingAt: Timestamp.now(),
          animalId: 'elephant-23',
          zoneId: 'zone-farmland',
          location: const AlertLocation(latitude: -1.2921, longitude: 36.8219),
          animalName: 'Elephant-23',
          locationLabel: 'Farmland Border',
        ),
      );
      await pumpDetail(tester);

      expect(find.byKey(const Key('alertStatusText')), findsNothing);
      expect(find.text('Ranger Amara is responding'), findsOneWidget);
      expect(find.byKey(const Key('otherOfficerButton')), findsOneWidget);

      final button = tester.widget<ElevatedButton>(
        find.byKey(const Key('otherOfficerButton')),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('resolved WITH resolvedAt shows a full resolution summary',
        (tester) async {
      alertRepository.setupAlert(
        'alert-001',
        Alert(
          alertId: 'alert-001',
          type: 'high_risk_movement',
          timestamp: Timestamp.now(),
          status: 'active',
          responseStatus: 'resolved',
          respondingOfficerId: 'ranger-amara',
          respondingOfficerName: 'Ranger Amara',
          respondingAt: Timestamp.fromDate(
            DateTime.now().subtract(const Duration(minutes: 30)),
          ),
          resolvedAt: Timestamp.now(),
          animalId: 'elephant-23',
          zoneId: 'zone-farmland',
          location: const AlertLocation(latitude: -1.2921, longitude: 36.8219),
          animalName: 'Elephant-23',
          locationLabel: 'Farmland Border',
        ),
      );
      await pumpDetail(tester);

      expect(find.byKey(const Key('alertStatusText')), findsOneWidget);
      expect(find.text('Situation resolved'), findsOneWidget);
      expect(find.byKey(const Key('unifiedStatusButton')), findsOneWidget);
      expect(find.text('Resolved'), findsWidgets);
      expect(find.byIcon(Icons.check_circle), findsAtLeastNWidgets(1));

      expect(find.text('Status: Resolved'), findsOneWidget);
      expect(find.text('Incident recorded'), findsOneWidget);
      expect(find.text('Incident Location'), findsOneWidget);

      expect(find.byKey(const Key('resolutionSummary')), findsOneWidget);
      expect(find.text('Resolution Summary'), findsOneWidget);
      expect(find.text('Responding ranger'), findsOneWidget);
      expect(find.text('Ranger Amara'), findsWidgets);
      expect(find.text('Just now'), findsWidgets); // a resolved time is shown

      final button = tester.widget<ElevatedButton>(
        find.byKey(const Key('unifiedStatusButton')),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('legacy resolved (null resolvedAt) renders safely, no fake time',
        (tester) async {
      alertRepository.setupAlert(
        'alert-001',
        Alert(
          alertId: 'alert-001',
          type: 'high_risk_movement',
          timestamp: Timestamp.now(),
          status: 'active',
          responseStatus: 'resolved',
          respondingOfficerId: 'ranger-amara',
          respondingOfficerName: 'Ranger Amara',
          respondingAt: Timestamp.fromDate(
            DateTime.now().subtract(const Duration(minutes: 30)),
          ),
          // resolvedAt intentionally omitted (legacy document).
          animalId: 'elephant-23',
          zoneId: 'zone-farmland',
          location: const AlertLocation(latitude: -1.2921, longitude: 36.8219),
          animalName: 'Elephant-23',
          locationLabel: 'Farmland Border',
        ),
      );
      await pumpDetail(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Situation resolved'), findsOneWidget);
      expect(find.text('Incident Location'), findsOneWidget);

      expect(find.byKey(const Key('resolutionSummary')), findsOneWidget);
      expect(find.text('Responding ranger'), findsOneWidget);
      expect(find.text('Ranger Amara'), findsWidgets);
      // No fabricated resolved-time row => exactly one check_circle (status line).
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('tapping Accepted claims with officerId "demo-user"',
        (tester) async {
      alertRepository.setupAlert(
        'alert-001',
        Alert(
          alertId: 'alert-001',
          type: 'high_risk_movement',
          timestamp: Timestamp.now(),
          status: 'active',
          responseStatus: 'unclaimed',
          animalId: 'elephant-23',
          zoneId: 'zone-farmland',
          location: const AlertLocation(latitude: -1.2921, longitude: 36.8219),
          animalName: 'Elephant-23',
          locationLabel: 'Farmland Border',
        ),
      );
      await pumpDetail(tester);

      await tester.scrollUntilVisible(find.text('Accepted'), 500.0);
      await tester.tap(find.byKey(const Key('unifiedStatusButton')));
      await tester.pumpAndSettle();

      expect(alertRepository.claimResponseCalls, hasLength(1));
      expect(
        alertRepository.claimResponseCalls.first['alertId'],
        equals('alert-001'),
      );
      expect(
        alertRepository.claimResponseCalls.first['officerId'],
        equals('demo-user'),
      );
    });

    testWidgets('renders in dark theme without overflow', (tester) async {
      alertRepository.setupAlert(
        'alert-001',
        Alert(
          alertId: 'alert-001',
          type: 'high_risk_movement',
          timestamp: Timestamp.now(),
          status: 'active',
          responseStatus: 'unclaimed',
          animalId: 'elephant-23',
          zoneId: 'zone-farmland',
          location: const AlertLocation(latitude: -1.2921, longitude: 36.8219),
          animalName: 'Elephant-23',
          locationLabel: 'Farmland Border',
        ),
      );
      await pumpDetail(tester, theme: AppTheme.dark());

      expect(find.text('Alert Details'), findsOneWidget);
      expect(find.text('Animal: Elephant-23'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows a not-found error state when the alert is missing',
        (tester) async {
      alertRepository.setupAlert('alert-001', null);
      await pumpDetail(tester);

      expect(find.text('Error Loading Alert'), findsOneWidget);
      expect(find.text('Alert not found'), findsOneWidget);
      expect(find.text('Back to Dashboard'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('shows a repository error state gracefully', (tester) async {
      alertRepository.setMockError('Database connection failed');
      await pumpDetail(tester);

      expect(find.text('Error Loading Alert'), findsOneWidget);
      expect(find.textContaining('Database connection failed'), findsOneWidget);
      expect(find.text('Back to Dashboard'), findsOneWidget);
    });
  });
}
