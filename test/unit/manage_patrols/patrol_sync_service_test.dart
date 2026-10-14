import 'package:flutter_test/flutter_test.dart';
import 'package:wildora/src/features/manage_patrols/data/patrol_local_store.dart';
import 'package:wildora/src/features/manage_patrols/data/patrol_models.dart';
import 'package:wildora/src/features/manage_patrols/data/patrol_sync_service.dart';

void main() {
  group('PatrolSyncService', () {
    late InMemoryPatrolLocalStore localStore;
    late PatrolSyncService syncService;

    setUp(() async {
      localStore = InMemoryPatrolLocalStore();
      await localStore.initialize();
      syncService = PatrolSyncService(
        localStore: localStore,
        remoteUpsert: (sessionId, data) async {},
      );
    });

    test('blocks dev simulation patrols from uploading to cloud', () async {
      final simSession = PatrolSession(
        sessionId: 'session_sim_001',
        assignedRouteId: 'route_001',
        rangerId: 'ranger_yala_001',
        routeName: 'Simulated Walk Route',
        plannedDistanceKm: 5.0,
        estimatedDurationMinutes: 60,
        lifecycleStatus: PatrolLifecycleStatus.completed,
        startTime: DateTime.now().subtract(const Duration(minutes: 30)),
        endTime: DateTime.now(),
        syncMetadata: const SyncMetadata(
          syncStatus: SyncStatus.pendingSync,
          isSimulation: true,
        ),
      );

      await localStore.saveSession(simSession);
      final result = await syncService.syncSession(simSession);

      expect(result.syncMetadata.syncStatus, SyncStatus.syncFailed);
      expect(result.syncMetadata.lastSyncError,
          contains('Simulated dev patrols are blocked'));
    });

    test('retains local data and sets syncFailed on simulated network error',
        () async {
      syncService.simulateFailure = true;

      final session = PatrolSession(
        sessionId: 'session_net_err_001',
        assignedRouteId: 'route_002',
        rangerId: 'ranger_yala_001',
        routeName: 'Boundary Patrol',
        plannedDistanceKm: 6.0,
        estimatedDurationMinutes: 90,
        lifecycleStatus: PatrolLifecycleStatus.completed,
        startTime: DateTime.now().subtract(const Duration(hours: 1)),
        endTime: DateTime.now(),
        syncMetadata: const SyncMetadata(
          syncStatus: SyncStatus.pendingSync,
          localRevision: 3,
        ),
      );

      await localStore.saveSession(session);
      final result = await syncService.syncSession(session);

      expect(result.syncMetadata.syncStatus, SyncStatus.syncFailed);
      expect(result.syncMetadata.lastSyncError, isNotNull);

      // Verify that local copy is intact in storage
      final stored = localStore
          .readAllSessions()
          .firstWhere((s) => s.sessionId == 'session_net_err_001');
      expect(stored.syncMetadata.syncStatus, SyncStatus.syncFailed);
      expect(stored.routeName, 'Boundary Patrol');
    });

    test(
        'stale acknowledgement detection preserves pendingSync if local revision advances',
        () async {
      final baseSession = PatrolSession(
        sessionId: 'session_stale_ack_001',
        assignedRouteId: 'route_003',
        rangerId: 'ranger_yala_001',
        routeName: 'Riverbank Patrol',
        plannedDistanceKm: 4.0,
        estimatedDurationMinutes: 60,
        lifecycleStatus: PatrolLifecycleStatus.active,
        startTime: DateTime.now(),
        syncMetadata: const SyncMetadata(
          syncStatus: SyncStatus.pendingSync,
          localRevision: 1, // in-flight upload has revision 1
        ),
      );

      // Meanwhile, local store receives a new point and advances to revision 2:
      final advancedSession = baseSession.copyWith(
        trackPoints: [
          TrackPoint(
            latitude: 6.35,
            longitude: 81.52,
            accuracy: 4.0,
            timestamp: DateTime.now(),
          ),
        ],
        syncMetadata: const SyncMetadata(
          syncStatus: SyncStatus.pendingSync,
          localRevision: 2,
        ),
      );
      await localStore.saveSession(advancedSession);

      // Now sync acknowledging in-flight revision 1 executes:
      final result = await syncService.syncSession(baseSession);

      // Because local store has revision 2 > acknowledged revision 1,
      // the session must remain pendingSync with serverRevision updated to 1
      expect(result.syncMetadata.syncStatus, SyncStatus.pendingSync);
      expect(result.syncMetadata.serverRevision, 1);
    });

    test(
        'getSynchronizedPatrolSessions requires real server records and refuses local-only unconfirmed history',
        () async {
      final session1 = PatrolSession(
        sessionId: 'hist_001',
        assignedRouteId: 'route_004',
        rangerId: 'ranger_yala_001',
        routeName: 'Zone A Morning Patrol',
        plannedDistanceKm: 5.0,
        estimatedDurationMinutes: 60,
        lifecycleStatus: PatrolLifecycleStatus.completed,
      );

      await localStore.saveSession(session1);

      // Without remote server confirmation, syncService does not label local-only history as synchronized
      final unconfirmed = await syncService.getSynchronizedPatrolSessions();
      expect(unconfirmed.isEmpty, isTrue);

      // When remote records are returned by server, manager review receives them:
      final serverConnectedService = PatrolSyncService(
        localStore: localStore,
        remoteReader: () async => [session1],
      );
      final coverage =
          await serverConnectedService.getSynchronizedPatrolSessions();
      expect(coverage.isNotEmpty, isTrue);
      expect(coverage.any((s) => s.sessionId == 'hist_001'), isTrue);
    });
  });
}
