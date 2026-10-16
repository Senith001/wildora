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

    /// Helper to build a mock alert with a given response status.
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

    testWidgets(
      'renders dashboard with no alerts message when stream is empty',
      (WidgetTester tester) async {
        // Setup: Empty alert stream
        alertRepository.seed([]);

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
        // Header block removed; the old title should no longer render.
        expect(find.text('High-Risk Movement Monitoring'), findsNothing);

        // Default tab (Active) empty state
        expect(find.text('No Active Alerts'), findsOneWidget);
        expect(
          find.text('All wildlife is safely outside high-risk zones'),
          findsOneWidget,
        );

        // Simulate button is gated off by default
        expect(find.text('Simulate'), findsNothing);
        expect(find.byIcon(Icons.developer_mode), findsNothing);
      },
    );

    testWidgets('renders the three tab selector labels', (
      WidgetTester tester,
    ) async {
      alertRepository.seed([]);

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

      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Responding'), findsOneWidget);
      expect(find.text('Resolved'), findsOneWidget);
    });

    testWidgets('renders only unclaimed alerts on the default Active tab', (
      WidgetTester tester,
    ) async {
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

      // Active tab shows only the unclaimed alert
      expect(find.text('Elephant-23'), findsOneWidget);
      expect(find.text('Farmland Border'), findsOneWidget);
      expect(find.text('URGENT'), findsOneWidget);

      // 'SEEN' status is never rendered
      expect(find.text('SEEN'), findsNothing);

      // The responding alert is filtered out on the Active tab
      expect(find.text('Buffalo-22'), findsNothing);

      // No "no alerts" message when matching alerts exist
      expect(find.text('No Active Alerts'), findsNothing);
    });

    testWidgets('switching to Responding tab shows only responding alerts', (
      WidgetTester tester,
    ) async {
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

      // Tap the Responding tab
      await tester.tap(find.text('Responding'));
      await tester.pumpAndSettle();

      // Only the responding alert is shown
      expect(find.text('Buffalo-22'), findsOneWidget);
      expect(find.text('RESPONDING'), findsOneWidget);

      // 'SEEN' status is never rendered
      expect(find.text('SEEN'), findsNothing);

      // Other statuses are filtered out
      expect(find.text('Elephant-23'), findsNothing);
      expect(find.text('Zebra-07'), findsNothing);
    });

    testWidgets('switching to Resolved tab shows only resolved alerts', (
      WidgetTester tester,
    ) async {
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

      // Tap the Resolved tab
      await tester.tap(find.text('Resolved'));
      await tester.pumpAndSettle();

      // Only the resolved alert is shown
      expect(find.text('Zebra-07'), findsOneWidget);
      expect(find.text('RESOLVED'), findsOneWidget);

      // 'SEEN' status is never rendered
      expect(find.text('SEEN'), findsNothing);

      // Unclaimed alert filtered out
      expect(find.text('Elephant-23'), findsNothing);
    });

    testWidgets('does not show a theme switcher in the app bar', (
      WidgetTester tester,
    ) async {
      alertRepository.seed([]);

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

      // The theme switcher was removed from the dashboard AppBar. Theme
      // switching now lives exclusively in Settings.
      expect(find.byType(PopupMenuButton<ThemeMode>), findsNothing);
      expect(find.byIcon(Icons.brightness_auto), findsNothing);

      // The AppBar exposes no theme menu entries.
      expect(find.text('System'), findsNothing);
      expect(find.text('Light'), findsNothing);
      expect(find.text('Dark'), findsNothing);
    });

    testWidgets('simulate location FAB is hidden when gated off', (
      WidgetTester tester,
    ) async {
      alertRepository.seed([]);

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

      // FAB is gated behind a dev flag and hidden by default
      expect(find.text('Simulate'), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
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
      alertRepository.seed([]);

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

      // Should not have any overflow or rendering errors
      expect(tester.takeException(), isNull);
    });

    testWidgets('navigates to alert detail when alert tapped', (
      WidgetTester tester,
    ) async {
      // Mock alert is 'unclaimed' so it appears on the default Active tab.
      alertRepository.seed([
        buildAlert(
          alertId: 'alert-001',
          responseStatus: 'unclaimed',
          animalName: 'Elephant-23',
          locationLabel: 'Farmland Border',
        ),
      ]);

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
