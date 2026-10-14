import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildora/src/features/manage_patrols/data/patrol_assignment_repository.dart';
import 'package:wildora/src/features/manage_patrols/data/patrol_auth_service.dart';
import 'package:wildora/src/features/manage_patrols/data/patrol_local_store.dart';
import 'package:wildora/src/features/manage_patrols/presentation/assign_patrol_screen.dart';

void main() {
  group('AssignPatrolScreen Widget Tests', () {
    late InMemoryPatrolLocalStore localStore;
    late InMemoryPatrolAssignmentRepository assignmentRepo;
    late InMemoryPatrolAuthService authService;

    setUp(() async {
      localStore = InMemoryPatrolLocalStore();
      await localStore.initialize();
      assignmentRepo =
          InMemoryPatrolAssignmentRepository(localStore: localStore);
      authService = InMemoryPatrolAuthService(
        currentRole: 'manager',
        currentUserId: 'manager_001',
        currentUserName: 'Head Warden',
      );
    });

    Widget createWidgetUnderTest() {
      return MaterialApp(
        home: AssignPatrolScreen(
          assignmentRepository: assignmentRepo,
          authService: authService,
        ),
      );
    }

    testWidgets('renders route assignment form inputs and dispatch header',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Dispatch Patrol Route'), findsOneWidget);
      expect(find.text('Route Name *'), findsOneWidget);
      expect(find.text('Conservation Sector / Area *'), findsOneWidget);
      expect(find.text('Add Checkpoint (Coord)'), findsOneWidget);
      expect(find.text('Save & Dispatch Route'), findsOneWidget);
    });

    testWidgets('shows validation error when submitting empty form',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final dispatchButton = find.text('Save & Dispatch Route');
      await tester.ensureVisible(dispatchButton);
      await tester.tap(dispatchButton);
      await tester.pumpAndSettle();

      expect(find.text('Please enter a route name'), findsOneWidget);
    });

    testWidgets('adds checkpoint using coordinate input fallback dialog',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final addCoordButton = find.text('Add Checkpoint (Coord)');
      await tester.ensureVisible(addCoordButton);
      await tester.tap(addCoordButton);
      await tester.pumpAndSettle();

      expect(find.text('Enter Checkpoint Coordinates'), findsOneWidget);

      // Enter valid lat and lng
      final latField = find.widgetWithText(TextFormField, 'Latitude (-90 to 90)');
      final lngField = find.widgetWithText(TextFormField, 'Longitude (-180 to 180)');
      final labelField = find.widgetWithText(TextFormField, 'Checkpoint Label / Name');

      await tester.enterText(latField, '6.3541');
      await tester.enterText(lngField, '81.5214');
      await tester.enterText(labelField, 'River Crossing North');

      await tester.tap(find.text('Add to Route'));
      await tester.pumpAndSettle();

      // Checkpoint badge should now be rendered
      expect(find.text('River Crossing North'), findsOneWidget);
      expect(find.text('6.35410, 81.52140'), findsOneWidget);
    });
  });
}
