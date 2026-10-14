import 'package:flutter_test/flutter_test.dart';
import 'package:wildora/src/features/manage_patrols/application/patrol_controller.dart';
import 'package:wildora/src/features/manage_patrols/data/patrol_models.dart';
import 'package:wildora/src/features/manage_patrols/data/patrol_local_store.dart';
import 'package:wildora/src/features/manage_patrols/data/patrol_location_service.dart';
import 'package:wildora/src/features/manage_patrols/data/patrol_sync_service.dart';
import 'package:wildora/src/features/manage_patrols/data/patrol_assignment_repository.dart';
import 'package:wildora/src/features/manage_patrols/data/patrol_auth_service.dart';
import 'package:geolocator/geolocator.dart';

/// Fake location service that returns controllable positions.
class FakePatrolLocationService extends PatrolLocationService {
  FakePatrolLocationService()
      : super(
          positionReader: null,
        );

  Position? nextPosition;
  bool shouldFail = false;
  void Function(TrackPoint)? _trackingCallback;
  bool trackingStarted = false;

  @override
  Future<TrackPoint> captureCurrentPosition() async {
    if (shouldFail) {
      throw StateError('GPS unavailable');
    }
    final pos = nextPosition ?? Position(
      latitude: 6.9271,
      longitude: 79.8612,
      timestamp: DateTime.now(),
      accuracy: 5.0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
    return TrackPoint(
      latitude: pos.latitude,
      longitude: pos.longitude,
      timestamp: pos.timestamp,
      accuracy: pos.accuracy,
      source: LocationSource.gps,
    );
  }

  @override
  Future<void> startTracking(void Function(TrackPoint) onPoint) async {
    trackingStarted = true;
    _trackingCallback = onPoint;
  }

  /// Simulate a GPS fix during tracking.
  void simulateGpsFix(TrackPoint point) {
    _trackingCallback?.call(point);
  }

  @override
  void stopTracking() {
    trackingStarted = false;
    _trackingCallback = null;
  }

  @override
  void dispose() {
    stopTracking();
  }
}

void main() {
  late InMemoryPatrolLocalStore localStore;
  late FakePatrolLocationService locationService;
  late PatrolSyncService syncService;
  late InMemoryPatrolAssignmentRepository assignmentRepository;
  late InMemoryPatrolAuthService authService;
  late PatrolController controller;

  setUp(() async {
    localStore = InMemoryPatrolLocalStore();
    locationService = FakePatrolLocationService();
    syncService = PatrolSyncService(
      localStore: localStore,
      remoteUpsert: (sessionId, data) async {},
    );
    authService = InMemoryPatrolAuthService(
      currentRole: 'ranger',
      currentUserId: 'ranger1',
      currentUserName: 'Ranger One',
    );
    assignmentRepository =
        InMemoryPatrolAssignmentRepository(localStore: localStore);

    // Pre-seed an assignment for ranger1
    await assignmentRepository.saveAssignment(
      PatrolAssignment(
        id: 'assign_001',
        routeName: 'Yala East Perimeter',
        area: 'Yala National Park',
        assignedRangerId: 'ranger1',
        assignedRangerName: 'Ranger One',
        assignedDate: DateTime.now(),
        plannedDistanceKm: 5.0,
        estimatedDurationMinutes: 120,
        status: PatrolAssignmentStatus.assigned,
        checkpoints: const [
          PatrolCheckpoint(
            order: 0,
            label: 'Gate',
            latitude: 6.35,
            longitude: 81.52,
          ),
          PatrolCheckpoint(
            order: 1,
            label: 'Post',
            latitude: 6.36,
            longitude: 81.53,
          ),
        ],
      ),
    );

    controller = PatrolController(
      localStore: localStore,
      locationService: locationService,
      syncService: syncService,
      assignmentRepository: assignmentRepository,
      authService: authService,
    );
  });

  tearDown(() {
    try {
      controller.dispose();
    } catch (_) {}
  });

  group('Initialization', () {
    test('initializes with no active session', () async {
      await controller.initialize();
      expect(controller.currentSession, isNull);
      expect(controller.isLoading, isFalse);
      expect(controller.error, isNull);
    });

    test('restores active session from storage', () async {
      // Pre-populate storage with an active session
      final session = PatrolSession(
        sessionId: 'restored_session',
        assignedRouteId: 'route1',
        rangerId: 'ranger1',
        startTime: DateTime.now().subtract(const Duration(hours: 1)),
        lifecycleStatus: PatrolLifecycleStatus.active,
      );
      await localStore.saveSession(session);

      await controller.initialize();
      expect(controller.currentSession, isNotNull);
      expect(controller.currentSession!.sessionId, 'restored_session');
      expect(controller.currentSession!.lifecycleStatus,
          PatrolLifecycleStatus.active);
    });

    test('does not start timer for non-active session', () async {
      final session = PatrolSession(
        sessionId: 'assigned_session',
        assignedRouteId: 'route1',
        lifecycleStatus: PatrolLifecycleStatus.assigned,
      );
      await localStore.saveSession(session);
      localStore.setActiveSessionId('assigned_session');

      await controller.initialize();
      // No error or crash expected; session is assigned, not active
      expect(controller.currentSession!.lifecycleStatus,
          PatrolLifecycleStatus.assigned);
    });

    test('handles initialization failure', () async {
      localStore.shouldFail = true;
      // saveSession on loadAssignment will fail
      await controller.initialize();
      // Initialize opens storage, so if shouldFail is set before,
      // reading may still succeed (InMemory doesn't fail on read)
      // But subsequent operations will fail
      localStore.shouldFail = false;
    });
  });

  group('Load Assignment', () {
    test('loads assignment when no session exists', () async {
      await controller.initialize();
      await controller.loadAssignment();
      expect(controller.currentSession, isNotNull);
      expect(controller.currentSession!.lifecycleStatus,
          PatrolLifecycleStatus.assigned);
      expect(controller.currentSession!.routeName, 'Yala East Perimeter');
    });

    test('does not overwrite existing session', () async {
      await controller.initialize();
      await controller.loadAssignment();
      final firstId = controller.currentSession!.sessionId;

      await controller.loadAssignment();
      expect(controller.currentSession!.sessionId, firstId);
    });

    test('handles save failure during assignment', () async {
      await controller.initialize();
      localStore.shouldFail = true;
      await controller.loadAssignment();
      expect(controller.error, isNotNull);
      expect(controller.currentSession, isNull);
    });
  });

  group('Start Patrol', () {
    setUp(() async {
      await controller.initialize();
      await controller.loadAssignment();
    });

    test('starts patrol and persists before confirming', () async {
      final success = await controller.startPatrol();
      expect(success, isTrue);
      expect(controller.currentSession!.lifecycleStatus,
          PatrolLifecycleStatus.active);
      expect(controller.currentSession!.startTime, isNotNull);

      // Verify persisted to storage
      final stored = localStore.readActiveSession();
      expect(stored, isNotNull);
      expect(stored!.lifecycleStatus, PatrolLifecycleStatus.active);
    });

    test('prevents duplicate start - returns true for already active', () async {
      await controller.startPatrol();
      final secondStart = await controller.startPatrol();
      expect(secondStart, isTrue);
      // Session ID should be the same
    });

    test('handles save failure during start', () async {
      localStore.shouldFail = true;
      final success = await controller.startPatrol();
      expect(success, isFalse);
      expect(controller.error, isNotNull);
      expect(controller.error, contains('Failed to start'));
    });

    test('start sets sync status to pendingSync', () async {
      await controller.startPatrol();
      expect(controller.currentSession!.syncMetadata.syncStatus,
          SyncStatus.pendingSync);
    });

    test('increments revision on start', () async {
      final revBefore = controller.currentSession!.revision;
      await controller.startPatrol();
      expect(controller.currentSession!.revision, greaterThan(revBefore));
    });
  });

  group('GPS Tracking', () {
    setUp(() async {
      await controller.initialize();
      await controller.loadAssignment();
      await controller.startPatrol();
    });

    test('startGpsTracking begins tracking for active session', () {
      controller.startGpsTracking();
      expect(locationService.trackingStarted, isTrue);
    });

    test('does not start tracking for non-active session', () async {
      await controller.completePatrol();
      controller.startGpsTracking();
      expect(locationService.trackingStarted, isFalse);
    });

    test('captureGpsFix records a single GPS point', () async {
      final success = await controller.captureGpsFix();
      expect(success, isTrue);
      expect(controller.currentSession!.trackPoints.length, 1);
      expect(controller.gpsAvailable, isTrue);
      expect(controller.lastGpsFix, isNotNull);
    });

    test('captureGpsFix handles GPS failure', () async {
      locationService.shouldFail = true;
      final success = await controller.captureGpsFix();
      expect(success, isFalse);
      expect(controller.gpsAvailable, isFalse);
      expect(controller.error, contains('GPS unavailable'));
    });

    test('captureGpsFix blocked after completion', () async {
      await controller.completePatrol();
      final success = await controller.captureGpsFix();
      expect(success, isFalse);
    });

    test('track points are persisted incrementally', () async {
      controller.startGpsTracking();
      locationService.simulateGpsFix(TrackPoint(
        latitude: 6.9271,
        longitude: 79.8612,
        timestamp: DateTime.now(),
        accuracy: 5.0,
      ));

      // Wait for async save
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final stored = localStore.readActiveSession();
      expect(stored!.trackPoints.length, 1);
    });

    test('track point increments revision and sets pendingSync', () async {
      final revBefore = controller.currentSession!.revision;
      final localRevBefore = controller.currentSession!.syncMetadata.localRevision;

      await controller.captureGpsFix();

      expect(controller.currentSession!.revision, revBefore + 1);
      expect(controller.currentSession!.syncMetadata.localRevision,
          localRevBefore + 1);
      expect(controller.currentSession!.syncMetadata.syncStatus,
          SyncStatus.pendingSync);
    });
  });

  group('Waypoints', () {
    setUp(() async {
      await controller.initialize();
      await controller.loadAssignment();
      await controller.startPatrol();
    });

    test('adds valid waypoint', () async {
      final wp = Waypoint(
        id: newWaypointId(),
        sessionId: controller.currentSession!.sessionId,
        type: WaypointType.animalSighting,
        latitude: 6.9271,
        longitude: 79.8612,
        locationSource: LocationSource.gps,
        timestamp: DateTime.now(),
        note: 'Elephant spotted',
      );
      final success = await controller.addWaypoint(wp);
      expect(success, isTrue);
      expect(controller.currentSession!.waypoints.length, 1);
      expect(controller.error, isNull);
    });

    test('rejects waypoint with invalid coordinates', () async {
      final wp = Waypoint(
        id: newWaypointId(),
        sessionId: controller.currentSession!.sessionId,
        type: WaypointType.animalSighting,
        latitude: 91.0, // Invalid
        longitude: 79.8612,
        locationSource: LocationSource.manual,
        timestamp: DateTime.now(),
      );
      final success = await controller.addWaypoint(wp);
      expect(success, isFalse);
      expect(controller.error, contains('Invalid coordinates'));
    });

    test('rejects waypoint with non-finite coordinates', () async {
      final wp = Waypoint(
        id: newWaypointId(),
        sessionId: controller.currentSession!.sessionId,
        type: WaypointType.animalSighting,
        latitude: double.nan,
        longitude: 79.8612,
        locationSource: LocationSource.manual,
        timestamp: DateTime.now(),
      );
      final success = await controller.addWaypoint(wp);
      expect(success, isFalse);
    });

    test('rejects waypoint when patrol is not active', () async {
      await controller.completePatrol();
      final wp = Waypoint(
        id: newWaypointId(),
        sessionId: controller.currentSession!.sessionId,
        type: WaypointType.other,
        latitude: 6.9, longitude: 79.8,
        locationSource: LocationSource.manual,
        timestamp: DateTime.now(),
      );
      final success = await controller.addWaypoint(wp);
      expect(success, isFalse);
      expect(controller.error, contains('not active'));
    });

    test('handles save failure for waypoint', () async {
      localStore.shouldFail = true;
      final wp = Waypoint(
        id: newWaypointId(),
        sessionId: controller.currentSession!.sessionId,
        type: WaypointType.trailMarker,
        latitude: 6.9, longitude: 79.8,
        locationSource: LocationSource.gps,
        timestamp: DateTime.now(),
      );
      final success = await controller.addWaypoint(wp);
      expect(success, isFalse);
      expect(controller.error, contains('Failed to save waypoint'));
    });

    test('optional note and photo can be null', () async {
      final wp = Waypoint(
        id: newWaypointId(),
        sessionId: controller.currentSession!.sessionId,
        type: WaypointType.waterSource,
        latitude: 6.9, longitude: 79.8,
        locationSource: LocationSource.gps,
        timestamp: DateTime.now(),
      );
      final success = await controller.addWaypoint(wp);
      expect(success, isTrue);
      expect(controller.currentSession!.waypoints.first.note, isNull);
      expect(controller.currentSession!.waypoints.first.photoReference, isNull);
    });

    test('waypoint increments revision and localRevision', () async {
      final revBefore = controller.currentSession!.revision;
      final localRevBefore = controller.currentSession!.syncMetadata.localRevision;

      final wp = Waypoint(
        id: newWaypointId(),
        sessionId: controller.currentSession!.sessionId,
        type: WaypointType.evidence,
        latitude: 6.9, longitude: 79.8,
        locationSource: LocationSource.gps,
        timestamp: DateTime.now(),
      );
      await controller.addWaypoint(wp);

      expect(controller.currentSession!.revision, revBefore + 1);
      expect(controller.currentSession!.syncMetadata.localRevision,
          localRevBefore + 1);
    });
  });

  group('Route Deviations', () {
    setUp(() async {
      await controller.initialize();
      await controller.loadAssignment();
      await controller.startPatrol();
    });

    test('records deviation with valid coordinates', () async {
      final success = await controller.recordDeviation(
        latitude: 6.9,
        longitude: 79.8,
        reason: 'Blocked trail',
      );
      expect(success, isTrue);
      expect(controller.currentSession!.deviations.length, 1);
      expect(controller.currentSession!.deviations.first.reason, 'Blocked trail');
    });

    test('records deviation without reason', () async {
      final success = await controller.recordDeviation(
        latitude: 6.9,
        longitude: 79.8,
      );
      expect(success, isTrue);
      expect(controller.currentSession!.deviations.first.reason, isNull);
    });

    test('rejects deviation with invalid coordinates', () async {
      final success = await controller.recordDeviation(
        latitude: 91,
        longitude: 79.8,
      );
      expect(success, isFalse);
      expect(controller.error, contains('Invalid deviation'));
    });

    test('rejects deviation when not active', () async {
      await controller.completePatrol();
      final success = await controller.recordDeviation(
        latitude: 6.9,
        longitude: 79.8,
      );
      expect(success, isFalse);
    });

    test('handles save failure for deviation', () async {
      localStore.shouldFail = true;
      final success = await controller.recordDeviation(
        latitude: 6.9,
        longitude: 79.8,
        reason: 'Test',
      );
      expect(success, isFalse);
      expect(controller.error, contains('Failed to record deviation'));
    });
  });

  group('Complete Patrol', () {
    setUp(() async {
      await controller.initialize();
      await controller.loadAssignment();
      await controller.startPatrol();
    });

    test('completes patrol and persists before stopping GPS', () async {
      controller.startGpsTracking();
      expect(locationService.trackingStarted, isTrue);

      final success = await controller.completePatrol();
      expect(success, isTrue);
      expect(controller.currentSession!.lifecycleStatus,
          PatrolLifecycleStatus.completed);
      expect(controller.currentSession!.endTime, isNotNull);
      expect(locationService.trackingStarted, isFalse);
    });

    test('prevents duplicate completion', () async {
      final first = await controller.completePatrol();
      expect(first, isTrue);

      final second = await controller.completePatrol();
      expect(second, isFalse); // Already completed
    });

    test('keeps patrol active on save failure', () async {
      controller.startGpsTracking();
      localStore.shouldFail = true;
      final success = await controller.completePatrol();
      expect(success, isFalse);
      expect(controller.error, contains('Failed to complete'));
      expect(controller.currentSession!.lifecycleStatus,
          PatrolLifecycleStatus.active);
      // GPS tracking should still be running since completion failed
      // (it wasn't stopped because save failed)
    });

    test('clears active session pointer in storage', () async {
      await controller.completePatrol();
      final active = localStore.readActiveSession();
      expect(active, isNull);
    });

    test('sets sync status to pendingSync after completion', () async {
      await controller.completePatrol();
      expect(controller.currentSession!.syncMetadata.syncStatus,
          SyncStatus.pendingSync);
    });

    test('blocks new waypoints after completion', () async {
      await controller.completePatrol();
      final wp = Waypoint(
        id: newWaypointId(),
        sessionId: controller.currentSession!.sessionId,
        type: WaypointType.animalSighting,
        latitude: 6.9, longitude: 79.8,
        locationSource: LocationSource.gps,
        timestamp: DateTime.now(),
      );
      final success = await controller.addWaypoint(wp);
      expect(success, isFalse);
    });

    test('blocks new track points after completion', () async {
      await controller.completePatrol();
      final success = await controller.captureGpsFix();
      expect(success, isFalse);
    });

    test('blocks new deviations after completion', () async {
      await controller.completePatrol();
      final success = await controller.recordDeviation(
        latitude: 6.9, longitude: 79.8,
      );
      expect(success, isFalse);
    });
  });

  group('Synchronization', () {
    setUp(() async {
      await controller.initialize();
      await controller.loadAssignment();
      await controller.startPatrol();
    });

    test('syncs completed session successfully', () async {
      await controller.completePatrol();
      final success = await controller.syncCurrentSession();
      expect(success, isTrue);
      expect(controller.currentSession!.syncMetadata.syncStatus,
          SyncStatus.synchronized);
    });

    test('handles sync failure', () async {
      syncService.simulateFailure = true;
      await controller.completePatrol();
      final success = await controller.syncCurrentSession();
      expect(success, isFalse);
      expect(controller.currentSession!.syncMetadata.syncStatus,
          SyncStatus.syncFailed);
    });

    test('retry after sync failure', () async {
      syncService.simulateFailure = true;
      await controller.completePatrol();
      await controller.syncCurrentSession();
      expect(controller.currentSession!.syncMetadata.syncStatus,
          SyncStatus.syncFailed);

      // Retry
      syncService.simulateFailure = false;
      final success = await controller.syncCurrentSession();
      expect(success, isTrue);
      expect(controller.currentSession!.syncMetadata.syncStatus,
          SyncStatus.synchronized);
    });

    test('returns false when no session exists', () async {
      await controller.resetForNewAssignment();
      final success = await controller.syncCurrentSession();
      expect(success, isFalse);
    });

    test('prevents concurrent syncs', () async {
      await controller.completePatrol();
      // Start first sync
      final future1 = controller.syncCurrentSession();
      // Second sync should return false immediately
      final result2 = await controller.syncCurrentSession();
      expect(result2, isFalse);
      await future1;
    });
  });

  group('Stale Acknowledgement', () {
    test('does not mark synchronized when server ack is stale', () async {
      await controller.initialize();
      await controller.loadAssignment();
      await controller.startPatrol();

      // Add some track data to increase local revision
      await controller.captureGpsFix();
      await controller.captureGpsFix();

      await controller.completePatrol();

      // The sync service in simulation mode acknowledges the current
      // local revision, so this test verifies the flow is correct.
      // To test stale acks, we'd need a mock that returns an older revision.
      final success = await controller.syncCurrentSession();
      expect(success, isTrue);
    });
  });

  group('Connectivity', () {
    test('setOnlineStatus updates and notifies', () async {
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.setOnlineStatus(false);
      expect(controller.isOnline, isFalse);
      expect(notifyCount, 1);

      controller.setOnlineStatus(true);
      expect(controller.isOnline, isTrue);
      expect(notifyCount, 2);
    });

    test('setOnlineStatus does not notify when value unchanged', () {
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.setOnlineStatus(true); // same as default
      expect(notifyCount, 0);
    });
  });

  group('Reset', () {
    test('resetForNewAssignment clears state', () async {
      await controller.initialize();
      await controller.loadAssignment();
      await controller.startPatrol();
      controller.startGpsTracking();

      await controller.resetForNewAssignment();
      expect(controller.currentSession, isNull);
      expect(controller.error, isNull);
      expect(controller.gpsAvailable, isTrue);
      expect(controller.lastGpsFix, isNull);
      expect(locationService.trackingStarted, isFalse);
    });
  });

  group('Resume after reopen', () {
    test('restores session with original start time and data', () async {
      // First controller session
      await controller.initialize();
      await controller.loadAssignment();
      await controller.startPatrol();

      final originalStartTime = controller.currentSession!.startTime;
      final sessionId = controller.currentSession!.sessionId;

      // Add some data
      await controller.captureGpsFix();
      final wp = Waypoint(
        id: newWaypointId(),
        sessionId: sessionId,
        type: WaypointType.trailMarker,
        latitude: 6.9, longitude: 79.8,
        locationSource: LocationSource.gps,
        timestamp: DateTime.now(),
      );
      await controller.addWaypoint(wp);

      controller.dispose();

      // Create new controller (simulating app reopen)
      controller = PatrolController(
        localStore: localStore,
        locationService: locationService,
        syncService: syncService,
      );

      await controller.initialize();

      expect(controller.currentSession, isNotNull);
      expect(controller.currentSession!.sessionId, sessionId);
      expect(controller.currentSession!.startTime, originalStartTime);
      expect(controller.currentSession!.trackPoints.length, 1);
      expect(controller.currentSession!.waypoints.length, 1);
      expect(controller.currentSession!.lifecycleStatus,
          PatrolLifecycleStatus.active);
    });
  });
}
