import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wildora/src/features/high_risk_movement/application/animal_monitoring_controller.dart';
import 'package:wildora/src/features/high_risk_movement/application/high_risk_zone_detection_service.dart';
import 'package:wildora/src/features/high_risk_movement/presentation/alert_detail_screen.dart';
import 'package:wildora/src/app/theme/app_theme.dart';
import 'package:wildora/src/data/models/alert.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../fakes/in_memory_repositories.dart';

void main() {
  group('AlertDetailScreen Widget Tests', () {
    late InMemoryAnimalRepository animalRepository;
    late InMemoryAlertRepository alertRepository;
    late InMemoryHighRiskZoneRepository zoneRepository;
    late InMemoryOfficerRepository officerRepository;
    late InMemoryDutyRosterRepository dutyRosterRepository;
    late InMemoryAlertRecipientRepository alertRecipientRepository;

    late AnimalMonitoringController controller;

    setUp(() {
      // Create in-memory repositories for testing
      animalRepository = InMemoryAnimalRepository();
      alertRepository = InMemoryAlertRepository();
      zoneRepository = InMemoryHighRiskZoneRepository();
      officerRepository = InMemoryOfficerRepository();
      dutyRosterRepository = InMemoryDutyRosterRepository();
      alertRecipientRepository = InMemoryAlertRecipientRepository();

      // Create detection service with repositories
      final detectionService = HighRiskZoneDetectionService(
        officerRepository: officerRepository,
        dutyRosterRepository: dutyRosterRepository,
        zoneRepository: zoneRepository,
      );

      // Create controller
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

    testWidgets('renders alert details with unclaimed response status', (
      WidgetTester tester,
    ) async {
      // Setup: Mock unclaimed alert
      final alert = Alert(
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
      );

      alertRepository.setupAlert('alert-001', alert);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: AlertDetailScreen(alertId: 'alert-001', controller: controller),
        ),
      );

      await tester.pumpAndSettle();

      // Verify critical banner
      expect(find.text('HIGH-RISK MOVEMENT DETECTED'), findsOneWidget);
      expect(find.text('Immediate attention required'), findsOneWidget);
      expect(find.byIcon(Icons.warning), findsOneWidget);

      // Verify animal information
      expect(find.text('Animal: Elephant-23'), findsOneWidget);
      expect(find.text('Status: Entered High-Risk Zone'), findsOneWidget);
      expect(find.text('Farmland Border'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);

      // Verify response section for unclaimed alert
      expect(find.text('Response Status'), findsOneWidget);
      expect(find.byKey(const Key('alertStatusText')), findsOneWidget);
      expect(find.text('No one responding'), findsOneWidget);
      expect(find.byKey(const Key('respondButton')), findsOneWidget);
      expect(find.text('Acknowledge Alert'), findsOneWidget);

      // Verify map placeholder
      expect(find.text('Location Map'), findsOneWidget);
    });

    testWidgets(
      'shows responding status when alert is claimed by current user',
      (WidgetTester tester) async {
        // Setup: Mock alert responded to by demo user
        final alert = Alert(
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
        );

        alertRepository.setupAlert('alert-001', alert);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: AlertDetailScreen(
              alertId: 'alert-001',
              controller: controller,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify response status shows user is responding
        expect(find.byKey(const Key('alertStatusText')), findsOneWidget);
        expect(find.text('You are responding'), findsOneWidget);
        expect(find.text('Mark as Resolved'), findsOneWidget);
        expect(find.byIcon(Icons.directions_run), findsOneWidget);

        // Should not show claim button
        expect(find.text("I'm responding / Heading there"), findsNothing);
      },
    );

    testWidgets('shows other officer responding when claimed by someone else', (
      WidgetTester tester,
    ) async {
      // Setup: Mock alert responded to by another officer
      final alert = Alert(
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
      );

      alertRepository.setupAlert('alert-001', alert);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: AlertDetailScreen(alertId: 'alert-001', controller: controller),
        ),
      );

      await tester.pumpAndSettle();

      // Verify response status shows other officer responding
      expect(find.byKey(const Key('alertStatusText')), findsOneWidget);
      expect(find.text('Ranger Amara is responding'), findsWidgets);
      expect(find.byKey(const Key('otherOfficerButton')), findsOneWidget);

      // Should not show claim or resolve buttons
      expect(find.text("I'm responding / Heading there"), findsNothing);
      expect(find.text('Mark as Resolved'), findsNothing);
    });

    testWidgets('shows resolved status when alert is resolved', (
      WidgetTester tester,
    ) async {
      // Setup: Mock resolved alert
      final alert = Alert(
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
        animalId: 'elephant-23',
        zoneId: 'zone-farmland',
        location: const AlertLocation(latitude: -1.2921, longitude: 36.8219),
        animalName: 'Elephant-23',
        locationLabel: 'Farmland Border',
      );

      alertRepository.setupAlert('alert-001', alert);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: AlertDetailScreen(alertId: 'alert-001', controller: controller),
        ),
      );

      await tester.pumpAndSettle();

      // Verify resolved status
      expect(find.byKey(const Key('alertStatusText')), findsOneWidget);
      expect(find.text('Situation resolved'), findsOneWidget);
      expect(find.text('Situation Resolved'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsAtLeastNWidgets(1));

      // Should not show action buttons
      expect(find.text("I'm responding / Heading there"), findsNothing);
      expect(find.text('Mark as Resolved'), findsNothing);
    });

    testWidgets('shows acknowledged status when alert is acknowledged', (
      WidgetTester tester,
    ) async {
      // Setup: Mock acknowledged alert
      final alert = Alert(
        alertId: 'alert-001',
        type: 'high_risk_movement',
        timestamp: Timestamp.now(),
        status: 'acknowledged',
        responseStatus: 'unclaimed',
        animalId: 'elephant-23',
        zoneId: 'zone-farmland',
        location: const AlertLocation(latitude: -1.2921, longitude: 36.8219),
        animalName: 'Elephant-23',
        locationLabel: 'Farmland Border',
      );

      alertRepository.setupAlert('alert-001', alert);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: AlertDetailScreen(alertId: 'alert-001', controller: controller),
        ),
      );

      await tester.pumpAndSettle();

      // Verify acknowledged status in acknowledge section
      expect(find.text('Alert Acknowledged'), findsOneWidget);
      expect(find.byIcon(Icons.visibility), findsAtLeastNWidgets(1));

      // Should not show acknowledge button
      expect(find.text('Acknowledge Alert'), findsNothing);
    });

    testWidgets('handles claim response button tap', (
      WidgetTester tester,
    ) async {
      // Setup: Mock unclaimed alert
      final alert = Alert(
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
      );

      alertRepository.setupAlert('alert-001', alert);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: AlertDetailScreen(alertId: 'alert-001', controller: controller),
        ),
      );

      await tester.pumpAndSettle();

      // Scroll to make buttons visible
      await tester.scrollUntilVisible(
        find.text("I'm responding / Heading there"),
        500.0,
      );

      // Tap claim response button
      await tester.tap(find.text("I'm responding / Heading there"));
      await tester.pumpAndSettle();

      // Verify claim response was called on repository
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

    testWidgets('handles acknowledge button tap', (WidgetTester tester) async {
      // Setup: Mock unclaimed, unacknowledged alert
      final alert = Alert(
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
      );

      alertRepository.setupAlert('alert-001', alert);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: AlertDetailScreen(alertId: 'alert-001', controller: controller),
        ),
      );

      await tester.pumpAndSettle();

      // Scroll to make buttons visible
      await tester.scrollUntilVisible(find.text('Acknowledge Alert'), 500.0);

      // Tap acknowledge button
      await tester.tap(find.text('Acknowledge Alert'));
      await tester.pumpAndSettle();

      // Verify acknowledge was called on repository
      expect(alertRepository.acknowledgeAlertCalls, hasLength(1));
      expect(alertRepository.acknowledgeAlertCalls.first, equals('alert-001'));
    });

    testWidgets('renders correctly in dark theme without overflow', (
      WidgetTester tester,
    ) async {
      // Setup: Mock alert
      final alert = Alert(
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
      );

      alertRepository.setupAlert('alert-001', alert);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: AlertDetailScreen(alertId: 'alert-001', controller: controller),
        ),
      );

      await tester.pumpAndSettle();

      // Verify screen renders without errors in dark mode
      expect(find.text('Alert Details'), findsOneWidget);
      expect(find.text('HIGH-RISK MOVEMENT DETECTED'), findsOneWidget);
      expect(find.text('Animal: Elephant-23'), findsOneWidget);

      // Should not have any overflow or rendering errors
      expect(tester.takeException(), isNull);

      // Verify no RenderFlex overflow errors in mobile preview size
      // The SingleChildScrollView should handle content overflow
      final Size screenSize =
          tester.binding.window.physicalSize /
          tester.binding.window.devicePixelRatio;
      expect(screenSize.height, greaterThan(0)); // Sanity check
    });

    testWidgets('handles error state when alert not found', (
      WidgetTester tester,
    ) async {
      // Setup: No alert in repository
      alertRepository.setupAlert('alert-001', null);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: AlertDetailScreen(alertId: 'alert-001', controller: controller),
        ),
      );

      await tester.pumpAndSettle();

      // Verify error state
      expect(find.text('Error Loading Alert'), findsOneWidget);
      expect(find.text('Alert not found'), findsOneWidget);
      expect(find.text('Back to Dashboard'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('handles repository error gracefully', (
      WidgetTester tester,
    ) async {
      // Setup: Repository error
      alertRepository.setMockError('Database connection failed');

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: AlertDetailScreen(alertId: 'alert-001', controller: controller),
        ),
      );

      await tester.pumpAndSettle();

      // Verify error state
      expect(find.text('Error Loading Alert'), findsOneWidget);
      expect(find.textContaining('Database connection failed'), findsOneWidget);
      expect(find.text('Back to Dashboard'), findsOneWidget);
    });
  });
}
