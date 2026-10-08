import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:wildora/src/data/models/alert.dart';
import 'package:wildora/src/features/high_risk_movement/application/animal_monitoring_controller.dart';
import 'package:wildora/src/features/high_risk_movement/application/high_risk_zone_detection_service.dart';
import 'package:wildora/src/features/high_risk_movement/presentation/monitoring_dashboard_screen.dart';
import 'package:wildora/src/app/theme/theme_controller.dart';
import 'package:wildora/src/app/theme/app_theme.dart';

import '../fakes/in_memory_repositories.dart';

void main() {
  group('MonitoringDashboardScreen Widget Tests', () {
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
      // Create in-memory repositories for testing
      animalRepository = InMemoryAnimalRepository();
      alertRepository = InMemoryAlertRepository();
      zoneRepository = InMemoryHighRiskZoneRepository();
      officerRepository = InMemoryOfficerRepository();
      dutyRosterRepository = InMemoryDutyRosterRepository();
      alertRecipientRepository = InMemoryAlertRecipientRepository();
      preferencesRepository = InMemoryUserPreferencesRepository();

      // Create detection service with repositories
      final detectionService = HighRiskZoneDetectionService(
        officerRepository: officerRepository,
        dutyRosterRepository: dutyRosterRepository,
        zoneRepository: zoneRepository,
      );

      // Create controllers
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

    testWidgets(
      'renders dashboard with no alerts message when stream is empty',
      (WidgetTester tester) async {
        // Setup: Empty alert stream
        alertRepository.setMockActiveAlerts([]);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: MonitoringDashboardScreen(
              controller: controller,
              themeController: themeController,
            ),
          ),
        );

        // Wait for stream to emit
        await tester.pumpAndSettle();

        // Verify dashboard elements
        expect(find.text('Monitoring Dashboard'), findsOneWidget);
        expect(find.text('High-Risk Movement Monitoring'), findsOneWidget);
        expect(find.text('No Active Alerts'), findsOneWidget);
        expect(
          find.text('All wildlife is safely outside high-risk zones'),
          findsOneWidget,
        );

        // Verify simulate button
        expect(find.text('Simulate'), findsOneWidget);
        expect(find.byIcon(Icons.developer_mode), findsOneWidget);
      },
    );

    testWidgets('renders alert list when stream has alerts', (
      WidgetTester tester,
    ) async {
      // Setup: Mock alerts
      final mockAlerts = [
        Alert(
          alertId: 'alert-001',
          type: 'high_risk_movement',
          timestamp: Timestamp.fromDate(DateTime.now()),
          status: 'active',
          responseStatus: 'unclaimed',
          animalId: 'elephant-23',
          zoneId: 'zone-001',
          location: const AlertLocation(latitude: -1.2921, longitude: 36.8219),
          animalName: 'Elephant-23',
          locationLabel: 'Farmland Border',
        ),
        Alert(
          alertId: 'alert-002',
          type: 'high_risk_movement',
          timestamp: Timestamp.fromDate(
            DateTime.now().subtract(const Duration(hours: 1)),
          ),
          status: 'active',
          responseStatus: 'responding',
          animalId: 'buffalo-22',
          zoneId: 'zone-002',
          location: const AlertLocation(latitude: -1.2950, longitude: 36.8200),
          animalName: 'Buffalo-22',
          locationLabel: 'Main Road',
        ),
      ];

      alertRepository.setMockActiveAlerts(mockAlerts);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: MonitoringDashboardScreen(
            controller: controller,
            themeController: themeController,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify alert list items
      expect(find.text('Elephant-23'), findsOneWidget);
      expect(find.text('Buffalo-22'), findsOneWidget);
      expect(find.text('Farmland Border'), findsOneWidget);
      expect(find.text('Main Road'), findsOneWidget);

      // Verify status badges
      expect(find.text('URGENT'), findsOneWidget);
      expect(find.text('RESPONDING'), findsOneWidget);

      // Verify no "no alerts" message
      expect(find.text('No Active Alerts'), findsNothing);
    });

    testWidgets('shows theme toggle in app bar', (WidgetTester tester) async {
      alertRepository.setMockActiveAlerts([]);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: MonitoringDashboardScreen(
            controller: controller,
            themeController: themeController,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find theme toggle button (popup menu button)
      expect(find.byIcon(Icons.brightness_auto), findsOneWidget);

      // Tap theme toggle to open menu
      await tester.tap(find.byIcon(Icons.brightness_auto));
      await tester.pumpAndSettle();

      // Verify theme options
      expect(find.text('System'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
    });

    testWidgets('opens simulate location sheet when FAB tapped', (
      WidgetTester tester,
    ) async {
      alertRepository.setMockActiveAlerts([]);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: MonitoringDashboardScreen(
            controller: controller,
            themeController: themeController,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap simulate FAB
      await tester.tap(find.text('Simulate'));
      await tester.pumpAndSettle();

      // Verify bottom sheet opened
      expect(find.byKey(const Key('simulateSheetTitle')), findsOneWidget);
      expect(find.text('Select Animal'), findsOneWidget);
    });

    testWidgets('handles error state gracefully', (WidgetTester tester) async {
      // Setup: Error in alert stream
      alertRepository.setMockError('Firestore connection failed');

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: MonitoringDashboardScreen(
            controller: controller,
            themeController: themeController,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify error display
      expect(find.text('Error loading alerts'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(
        find.textContaining('Firestore connection failed'),
        findsOneWidget,
      );
    });

    testWidgets('renders correctly in dark theme', (WidgetTester tester) async {
      alertRepository.setMockActiveAlerts([]);

      // Set dark theme
      await themeController.setThemeMode(ThemeMode.dark);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.dark,
          home: MonitoringDashboardScreen(
            controller: controller,
            themeController: themeController,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify screen renders without errors in dark mode
      expect(find.text('Monitoring Dashboard'), findsOneWidget);
      expect(find.text('No Active Alerts'), findsOneWidget);
      expect(find.byIcon(Icons.dark_mode), findsOneWidget);

      // Should not have any overflow or rendering errors
      expect(tester.takeException(), isNull);
    });

    testWidgets('navigates to alert detail when alert tapped', (
      WidgetTester tester,
    ) async {
      final mockAlerts = [
        Alert(
          alertId: 'alert-001',
          type: 'high_risk_movement',
          timestamp: Timestamp.fromDate(DateTime.now()),
          status: 'active',
          responseStatus: 'unclaimed',
          animalId: 'elephant-23',
          zoneId: 'zone-001',
          location: const AlertLocation(latitude: -1.2921, longitude: 36.8219),
          animalName: 'Elephant-23',
          locationLabel: 'Farmland Border',
        ),
      ];

      alertRepository.setMockActiveAlerts(mockAlerts);

      bool navigatedToAlert = false;
      String? alertId;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: MonitoringDashboardScreen(
            controller: controller,
            themeController: themeController,
          ),
          routes: {
            '/alert': (context) {
              final args = ModalRoute.of(context)!.settings.arguments as String;
              navigatedToAlert = true;
              alertId = args;
              return Scaffold(
                appBar: AppBar(title: Text('Alert Detail - $args')),
                body: Center(child: Text('Alert Detail Screen for $args')),
              );
            },
          },
        ),
      );

      await tester.pumpAndSettle();

      // Tap on alert item
      await tester.tap(find.text('Elephant-23'));
      await tester.pumpAndSettle();

      // Verify navigation occurred
      expect(navigatedToAlert, isTrue);
      expect(alertId, equals('alert-001'));
      expect(find.text('Alert Detail Screen for alert-001'), findsOneWidget);
    });
  });
}
