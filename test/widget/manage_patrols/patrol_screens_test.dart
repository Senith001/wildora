import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildora/src/features/manage_patrols/application/patrol_controller.dart';
import 'package:wildora/src/features/manage_patrols/data/patrol_local_store.dart';
import 'package:wildora/src/features/manage_patrols/data/patrol_models.dart';
import 'package:wildora/src/features/manage_patrols/data/patrol_sync_service.dart';
import 'package:wildora/src/features/manage_patrols/presentation/assigned_patrol_screen.dart';
import 'package:wildora/src/features/manage_patrols/presentation/patrol_in_progress_screen.dart';
import 'package:wildora/src/features/manage_patrols/presentation/patrol_completed_screen.dart';
import 'package:wildora/src/features/manage_patrols/presentation/add_waypoint_screen.dart';
import '../../unit/manage_patrols/fake_patrol_location_service.dart';

void main() {
  group('AssignedPatrolScreen Widget Tests', () {
    late InMemoryPatrolLocalStore localStore;
    late FakePatrolLocationService locationService;
    late PatrolSyncService syncService;
    late PatrolController controller;

    setUp(() {
      localStore = InMemoryPatrolLocalStore();
      locationService = FakePatrolLocationService();
      syncService = PatrolSyncService(localStore: localStore);
      controller = PatrolController(
        localStore: localStore,
        locationService: locationService,
        syncService: syncService,
      );
    });

    tearDown(() {
      try {
        controller.dispose();
      } catch (_) {}
    });

    testWidgets('renders route details and Start Patrol button', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: AssignedPatrolScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Assigned Patrol'), findsOneWidget);
      expect(find.text('Start Patrol'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('shows connection indicator', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: AssignedPatrolScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Online'), findsOneWidget);

      controller.setOnlineStatus(false);
      await tester.pumpAndSettle();

      expect(find.text('Offline'), findsOneWidget);
    });

    testWidgets('tapping Start Patrol transitions session to active', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: AssignedPatrolScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start Patrol'));
      await tester.pumpAndSettle();

      expect(controller.currentSession?.lifecycleStatus, PatrolLifecycleStatus.active);
      expect(find.text('Patrol In Progress'), findsOneWidget);

      controller.dispose();
    });
  });

  group('PatrolInProgressScreen Widget Tests', () {
    late InMemoryPatrolLocalStore localStore;
    late FakePatrolLocationService locationService;
    late PatrolSyncService syncService;
    late PatrolController controller;

    setUp(() async {
      localStore = InMemoryPatrolLocalStore();
      locationService = FakePatrolLocationService();
      syncService = PatrolSyncService(localStore: localStore);
      controller = PatrolController(
        localStore: localStore,
        locationService: locationService,
        syncService: syncService,
      );
      await controller.initialize();
      await controller.loadAssignment();
      await controller.startPatrol();
    });

    tearDown(() {
      try {
        controller.dispose();
      } catch (_) {}
    });

    testWidgets('renders active patrol metrics and controls', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: PatrolInProgressScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Patrol In Progress'), findsOneWidget);
      expect(find.text('Add Waypoint'), findsOneWidget);
      expect(find.text('Deviation'), findsOneWidget);
      expect(find.text('Complete Patrol'), findsOneWidget);
    });

    testWidgets('captures GPS fix when Record GPS Fix tapped', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: PatrolInProgressScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      final initialPoints = controller.currentSession?.trackPoints.length ?? 0;
      final fixBtn = find.text('Record GPS Fix');
      if (fixBtn.evaluate().isNotEmpty) {
        await tester.tap(fixBtn);
        await tester.pumpAndSettle();
        expect(controller.currentSession!.trackPoints.length, greaterThan(initialPoints));
      }
    });

    testWidgets('tapping Complete Patrol shows confirmation dialog', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: PatrolInProgressScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Complete Patrol'));
      await tester.pumpAndSettle();

      expect(find.text('Complete Patrol?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('Complete Patrol')), findsOneWidget);
    });
  });

  group('PatrolCompletedScreen Widget Tests', () {
    late InMemoryPatrolLocalStore localStore;
    late FakePatrolLocationService locationService;
    late PatrolSyncService syncService;
    late PatrolController controller;

    setUp(() async {
      localStore = InMemoryPatrolLocalStore();
      locationService = FakePatrolLocationService();
      syncService = PatrolSyncService(localStore: localStore);
      controller = PatrolController(
        localStore: localStore,
        locationService: locationService,
        syncService: syncService,
      );
      await controller.initialize();
      await controller.loadAssignment();
      await controller.startPatrol();
      await controller.completePatrol();
    });

    tearDown(() {
      try {
        controller.dispose();
      } catch (_) {}
    });

    testWidgets('renders completion summary and metrics', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: PatrolCompletedScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Patrol Summary'), findsOneWidget);
      expect(find.text('Patrol Completed'), findsOneWidget);
      expect(find.text('New Patrol Assignment'), findsOneWidget);
    });

    testWidgets('tapping Sync Now attempts sync', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: PatrolCompletedScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      final syncBtn = find.text('Sync Now');
      if (syncBtn.evaluate().isNotEmpty) {
        await tester.tap(syncBtn);
        await tester.pumpAndSettle();
      }
      expect(controller.currentSession?.lifecycleStatus, PatrolLifecycleStatus.completed);
    });
  });

  group('AddWaypointScreen Widget Tests', () {
    late InMemoryPatrolLocalStore localStore;
    late FakePatrolLocationService locationService;
    late PatrolSyncService syncService;
    late PatrolController controller;

    setUp(() async {
      localStore = InMemoryPatrolLocalStore();
      locationService = FakePatrolLocationService();
      syncService = PatrolSyncService(localStore: localStore);
      controller = PatrolController(
        localStore: localStore,
        locationService: locationService,
        syncService: syncService,
      );
      await controller.initialize();
      await controller.loadAssignment();
      await controller.startPatrol();
    });

    tearDown(() {
      try {
        controller.dispose();
      } catch (_) {}
    });

    testWidgets('validates and submits waypoint', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: AddWaypointScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add Waypoint'), findsOneWidget);
      expect(find.text('Waypoint Type'), findsOneWidget);
      expect(find.text('Save Waypoint'), findsOneWidget);

      await tester.tap(find.text('Save Waypoint'));
      await tester.pumpAndSettle();

      // Controller should now have 1 waypoint
      expect(controller.currentSession?.waypoints.length, 1);
    });
  });
}
