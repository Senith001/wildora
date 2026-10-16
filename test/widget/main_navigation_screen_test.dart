import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:wildora/src/app/main_navigation_screen.dart';
import 'package:wildora/src/app/theme/app_theme.dart';
import 'package:wildora/src/app/theme/theme_controller.dart';
import 'package:wildora/src/data/models/alert.dart';
import 'package:wildora/src/features/high_risk_movement/application/animal_monitoring_controller.dart';
import 'package:wildora/src/features/high_risk_movement/application/high_risk_zone_detection_service.dart';

import '../fakes/in_memory_repositories.dart';

void main() {
  group('MainNavigationScreen Widget Tests', () {
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
      // In-memory repositories keep the shell fully deterministic and
      // Firestore-free (the shell only builds live controllers when deps
      // are not injected).
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

      // Seed a couple of alerts so the embedded dashboard's Active tab
      // renders alert content when the Alert tab is opened.
      alertRepository.seed([
        Alert(
          alertId: 'alert-001',
          type: 'high_risk_movement',
          timestamp: Timestamp.now(),
          status: 'active',
          responseStatus: AlertResponseStatus.unclaimed,
          animalId: 'elephant-id',
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
          responseStatus: AlertResponseStatus.responding,
          animalId: 'buffalo-id',
          zoneId: 'zone-001',
          location: const AlertLocation(latitude: -1.2800, longitude: 36.8100),
          animalName: 'Buffalo-22',
          locationLabel: 'Main Road',
        ),
      ]);
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

    /// Builds the shell with injected in-memory controllers and a stub
    /// alert-detail route (so taps that push '/alert' do not crash).
    Widget buildShell() {
      return MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: MainNavigationScreen(
          monitoringController: controller,
          themeController: themeController,
        ),
        routes: {
          '/alert': (context) =>
              const Scaffold(body: Text('AlertDetailStub')),
        },
      );
    }

    testWidgets('renders the four-item shell nav without a Profile tab', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildShell());
      await tester.pumpAndSettle();

      // All four tab labels are present in the bottom nav.
      expect(find.text('Home'), findsWidgets);
      expect(find.text('Incident'), findsOneWidget);
      expect(find.text('Alert'), findsOneWidget);
      expect(find.text('Settings'), findsWidgets);

      // The old Profile tab must not exist anywhere in the shell.
      expect(find.text('Profile'), findsNothing);
    });

    testWidgets('tapping the Alert tab shows the Monitoring Dashboard', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildShell());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alert'));
      await tester.pumpAndSettle();

      // The embedded dashboard content is now visible.
      expect(find.text('High-Risk Movement Monitoring'), findsOneWidget);
      // Dashboard Active tab (and the seeded unclaimed alert) render.
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Elephant-23'), findsOneWidget);
    });

    testWidgets(
      'Settings tab shows settings and toggles work',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildShell());
        await tester.pumpAndSettle();

        // Open Settings tab.
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();

        // Settings screen and its monitoring toggles are present.
        expect(find.byKey(const Key('settingsScreen')), findsOneWidget);
        expect(find.text('Continuous GPS Monitoring'), findsOneWidget);
        expect(find.text('Power Saving Mode'), findsOneWidget);

        // Power Saving Mode defaults to false; tapping toggles it to true.
        final powerSavingFinder = find.byKey(const Key('powerSavingSwitch'));
        expect(powerSavingFinder, findsOneWidget);
        expect(
          tester.widget<SwitchListTile>(powerSavingFinder).value,
          isFalse,
        );

        await tester.tap(powerSavingFinder);
        await tester.pump();

        expect(
          tester.widget<SwitchListTile>(powerSavingFinder).value,
          isTrue,
        );

        // Selecting Dark updates the ThemeController.
        await tester.tap(find.text('Dark'));
        await tester.pump();

        expect(themeController.themeMode, ThemeMode.dark);
      },
    );
  });
}
