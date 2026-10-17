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

      // Banner removed: critical banner no longer rendered
      expect(find.text('HIGH-RISK MOVEMENT DETECTED'), findsNothing);
      expect(find.text('Immediate attention required'), findsNothing);
      expect(find.byIcon(Icons.warning), findsNothing);

      // Verify animal information
      expect(find.text('Animal: Elephant-23'), findsOneWidget);
      expect(find.text('Status: In High-Risk Zone'), findsOneWidget);
      expect(find.text('Farmland Border'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);

      // Verify response section for unclaimed alert
      expect(find.text('Response Status'), findsOneWidget);
      expect(find.byKey(const Key('alertStatusText')), findsOneWidget);
      expect(find.text('No one responding'), findsOneWidget);
      expect(find.byKey(const Key('unifiedStatusButton')), findsOneWidget);
      expect(find.text('Accepted'), findsOneWidget);

      // No resolution summary for an active unclaimed alert
      expect(find.byKey(const Key('resolutionSummary')), findsNothing);

      // Verify View on Map button exists
      expect(find.byKey(const Key('viewOnMapButton')), findsOneWidget);
      expect(find.text('View on Map'), findsOneWidget);

      // Verify incident location section header
      expect(find.text('Incident Location'), findsOneWidget);
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
        expect(find.byKey(const Key('unifiedStatusButton')), findsOneWidget);
        expect(find.text('Responding'), findsOneWidget);
        expect(find.byIcon(Icons.directions_run), findsOneWidget);

        // Active (non-resolved) workflow: status row still active, no
        // resolution summary, incident location header present.
        expect(find.text('Status: In High-Risk Zone'), findsOneWidget);
        expect(find.text('Incident Location'), findsOneWidget);
        expect(find.byKey(const Key('resolutionSummary')), findsNothing);
      },
    );

    testWidgets('handles resolve response button tap when user is responding', (
      WidgetTester tester,
    ) async {
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
          home: AlertDetailScreen(alertId: 'alert-001', controller: controller),
        ),
      );

      await tester.pumpAndSettle();

      // Scroll to make button visible
      await tester.scrollUntilVisible(
        find.text('Responding'),
        500.0,
      );

      // Tap the unified status button (should resolve)
      await tester.tap(find.byKey(const Key('unifiedStatusButton')));
      await tester.pumpAndSettle();

      // Verify resolve response was called on repository
      expect(alertRepository.resolveResponseCalls, hasLength(1));
      expect(alertRepository.resolveResponseCalls.first, equals('alert-001'));
    });

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

      // Verify response status shows other officer responding.
      // The status line above the button is suppressed for the other-officer
      // case, so 'Ranger Amara is responding' now appears ONLY on the button.
      expect(find.byKey(const Key('alertStatusText')), findsNothing);
      expect(find.text('Ranger Amara is responding'), findsOneWidget);
      expect(find.byKey(const Key('otherOfficerButton')), findsOneWidget);

      // Verify the other officer button is disabled and shows officer name
      final otherOfficerButton = tester.widget<ElevatedButton>(
        find.byKey(const Key('otherOfficerButton')),
      );
      expect(otherOfficerButton.onPressed, isNull); // Button should be disabled
    });

    testWidgets('shows resolved status when alert is resolved', (
      WidgetTester tester,
    ) async {
      // Setup: Mock resolved alert WITH reliable resolution data
      final resolvedAt = Timestamp.now();
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
        resolvedAt: resolvedAt,
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
      expect(find.byKey(const Key('unifiedStatusButton')), findsOneWidget);
      expect(find.text('Resolved'), findsWidgets);
      expect(find.byIcon(Icons.check_circle), findsAtLeastNWidgets(1));

      // Status-driven info rows for resolved (no longer hard-coded)
      expect(find.text('Status: Resolved'), findsOneWidget);
      expect(find.text('Incident recorded'), findsOneWidget);

      // Incident Location header + Resolved chip (chip reuses 'Resolved' text)
      expect(find.text('Incident Location'), findsOneWidget);

      // Resolution summary present with ranger name and a resolved time
      expect(find.byKey(const Key('resolutionSummary')), findsOneWidget);
      expect(find.text('Resolution Summary'), findsOneWidget);
      expect(find.text('Responding ranger'), findsOneWidget);
      expect(find.text('Ranger Amara'), findsWidgets);
      // A resolved timestamp line is shown ('Just now' for a near-now time).
      expect(find.text('Just now'), findsWidgets);

      // View on Map still present for resolved alerts
      expect(find.byKey(const Key('viewOnMapButton')), findsOneWidget);
      expect(find.text('View on Map'), findsOneWidget);

      // Verify the resolved button is disabled
      final resolvedButton = tester.widget<ElevatedButton>(
        find.byKey(const Key('unifiedStatusButton')),
      );
      expect(resolvedButton.onPressed, isNull); // Button should be disabled
    });

    testWidgets(
      'resolved legacy alert without resolvedAt renders safely',
      (WidgetTester tester) async {
        // Setup: Legacy resolved alert with NO resolvedAt (backward-compat)
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
          // resolvedAt intentionally omitted (null) -> legacy document
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

        // Renders without exception
        expect(tester.takeException(), isNull);

        // Resolved status still rendered
        expect(find.text('Situation resolved'), findsOneWidget);
        expect(find.text('Incident Location'), findsOneWidget);

        // Resolution summary does not crash; responding ranger line may show
        // since respondingOfficerName is set, but NO fabricated timestamp.
        expect(find.byKey(const Key('resolutionSummary')), findsOneWidget);
        expect(find.text('Responding ranger'), findsOneWidget);
        expect(find.text('Ranger Amara'), findsWidgets);
        // No resolved-time row is fabricated. The resolved-time row renders a
        // check_circle icon; without resolvedAt it is omitted, leaving only
        // the single check_circle in the status line.
        expect(find.byIcon(Icons.check_circle), findsOneWidget);

        // View on Map still present
        expect(find.byKey(const Key('viewOnMapButton')), findsOneWidget);
        expect(find.text('View on Map'), findsOneWidget);
      },
    );

    testWidgets('shows Accepted button for unclaimed active alert', (
      WidgetTester tester,
    ) async {
      // Setup: Mock unclaimed active alert
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

      // Verify the screen still renders animal info; banner removed
      expect(find.text('HIGH-RISK MOVEMENT DETECTED'), findsNothing);
      expect(find.text('Animal: Elephant-23'), findsOneWidget);

      // Verify unified button reflects the response status
      expect(find.byKey(const Key('unifiedStatusButton')), findsOneWidget);
      expect(find.text('Accepted'), findsOneWidget); // Should show Accepted since responseStatus is unclaimed

      // Should not show old SEEN or acknowledge button
      expect(find.text('SEEN'), findsNothing);
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
        find.text('Accepted'),
        500.0,
      );

      // Tap unified status button (Accepted)
      await tester.tap(find.byKey(const Key('unifiedStatusButton')));
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
      expect(find.text('HIGH-RISK MOVEMENT DETECTED'), findsNothing);
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
