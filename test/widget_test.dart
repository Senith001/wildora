import 'package:flutter_test/flutter_test.dart';

import 'package:wildora/src/app/app.dart';
import 'package:wildora/src/app/app_router.dart';
import 'package:wildora/src/app/theme/theme_controller.dart';
import 'package:wildora/src/features/high_risk_movement/application/animal_monitoring_controller.dart';
import 'package:wildora/src/features/high_risk_movement/application/high_risk_zone_detection_service.dart';

import 'fakes/in_memory_repositories.dart';

void main() {
  testWidgets('App loads and displays HomeScreen', (WidgetTester tester) async {
    // Create fake repository and theme controller for testing
    final fakePrefsRepository = InMemoryUserPreferencesRepository();
    final themeController = ThemeController(fakePrefsRepository);

    // Create in-memory repositories for testing
    final animalRepository = InMemoryAnimalRepository();
    final alertRepository = InMemoryAlertRepository();
    final zoneRepository = InMemoryHighRiskZoneRepository();
    final officerRepository = InMemoryOfficerRepository();
    final dutyRosterRepository = InMemoryDutyRosterRepository();
    final alertRecipientRepository = InMemoryAlertRecipientRepository();

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

    // Create router with in-memory dependencies
    final router = AppRouter(
      monitoringController: monitoringController,
      themeController: themeController,
    );

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      WildoraApp(themeController: themeController, router: router),
    );

    // Verify that the app displays the AppBar title.
    expect(find.text('Wildora'), findsOneWidget);

    // Verify that the welcome text is displayed.
    expect(find.text('Welcome to Wildora'), findsOneWidget);

    // Verify that the status text is displayed.
    expect(find.text('Initial setup is working ✅'), findsOneWidget);

    // Cleanup
    themeController.dispose();
    fakePrefsRepository.dispose();
  });
}
