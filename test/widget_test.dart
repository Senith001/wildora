import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wildora/src/app/main_navigation_screen.dart';
import 'package:wildora/src/app/theme/app_theme.dart';
import 'package:wildora/src/app/theme/theme_controller.dart';
import 'package:wildora/src/app/widgets/app_shell_bottom_nav.dart';
import 'package:wildora/src/features/high_risk_movement/application/animal_monitoring_controller.dart';
import 'package:wildora/src/features/high_risk_movement/application/high_risk_zone_detection_service.dart';

import 'fakes/in_memory_repositories.dart';

void main() {
  testWidgets('App shell builds the 4-tab MainNavigationScreen', (
    WidgetTester tester,
  ) async {
    // Build with injected in-memory dependencies so the shell stays
    // deterministic and Firestore-free. When deps are omitted, the shell
    // lazily constructs Firestore-backed controllers, which is not available
    // (and not desirable) in a unit/widget test environment.
    final fakePrefsRepository = InMemoryUserPreferencesRepository();
    final themeController = ThemeController(fakePrefsRepository);

    final animalRepository = InMemoryAnimalRepository();
    final alertRepository = InMemoryAlertRepository();
    final zoneRepository = InMemoryHighRiskZoneRepository();
    final officerRepository = InMemoryOfficerRepository();
    final dutyRosterRepository = InMemoryDutyRosterRepository();
    final alertRecipientRepository = InMemoryAlertRecipientRepository();

    final detectionService = HighRiskZoneDetectionService(
      officerRepository: officerRepository,
      dutyRosterRepository: dutyRosterRepository,
      zoneRepository: zoneRepository,
    );

    final monitoringController = AnimalMonitoringController(
      animalRepository: animalRepository,
      alertRepository: alertRepository,
      alertRecipientRepository: alertRecipientRepository,
      detectionService: detectionService,
      zoneRepository: zoneRepository,
    );

    alertRepository.seed([]);

    // Build the app shell and trigger a frame.
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: MainNavigationScreen(
          monitoringController: monitoringController,
          themeController: themeController,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify the shell renders with its 4-tab bottom navigation.
    expect(find.byType(AppShellBottomNav), findsOneWidget);

    // Default tab is Home (both the nav label and the home content).
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Welcome to Wildora'), findsOneWidget);

    // The nav does not include a Profile tab.
    expect(find.text('Profile'), findsNothing);

    // Cleanup
    monitoringController.dispose();
    themeController.dispose();
    animalRepository.dispose();
    alertRepository.dispose();
    zoneRepository.dispose();
    officerRepository.dispose();
    dutyRosterRepository.dispose();
    alertRecipientRepository.dispose();
    fakePrefsRepository.dispose();
  });
}
