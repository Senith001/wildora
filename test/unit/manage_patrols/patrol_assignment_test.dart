import 'package:flutter_test/flutter_test.dart';
import 'package:wildora/src/features/manage_patrols/data/patrol_assignment_repository.dart';
import 'package:wildora/src/features/manage_patrols/data/patrol_local_store.dart';
import 'package:wildora/src/features/manage_patrols/data/patrol_models.dart';

void main() {
  group('PatrolCheckpoint', () {
    test('serialization roundtrip', () {
      const cp = PatrolCheckpoint(
        order: 1,
        latitude: 6.4521,
        longitude: 81.3342,
        label: 'North Gate Checkpoint',
      );

      final map = cp.toMap();
      final restored = PatrolCheckpoint.fromMap(map);

      expect(restored.order, 1);
      expect(restored.latitude, 6.4521);
      expect(restored.longitude, 81.3342);
      expect(restored.label, 'North Gate Checkpoint');
    });

    test('validates coordinate range', () {
      expect(PatrolCheckpoint.isValidLatitude(6.45), isTrue);
      expect(PatrolCheckpoint.isValidLatitude(91.0), isFalse);
      expect(PatrolCheckpoint.isValidLatitude(-91.0), isFalse);

      expect(PatrolCheckpoint.isValidLongitude(81.33), isTrue);
      expect(PatrolCheckpoint.isValidLongitude(181.0), isFalse);
      expect(PatrolCheckpoint.isValidLongitude(-181.0), isFalse);
    });
  });

  group('PatrolAssignment', () {
    test('serialization roundtrip', () {
      final assignment = PatrolAssignment(
        id: 'asgn_test_001',
        routeName: 'Block 1 River Perimeter',
        area: 'Yala Sector Alpha',
        assignedRangerId: 'ranger_yala_001',
        assignedRangerName: 'Mihiranga R P',
        assignedByManagerId: 'mgr_001',
        assignedDate: DateTime.utc(2026, 10, 14),
        plannedDistanceKm: 7.5,
        estimatedDurationMinutes: 120,
        status: PatrolAssignmentStatus.assigned,
        checkpoints: const [
          PatrolCheckpoint(
            order: 1,
            latitude: 6.35,
            longitude: 81.52,
            label: 'Start Point',
          ),
          PatrolCheckpoint(
            order: 2,
            latitude: 6.38,
            longitude: 81.54,
            label: 'Water Hole',
          ),
        ],
      );

      final map = assignment.toMap();
      final restored = PatrolAssignment.fromMap(map);

      expect(restored.id, 'asgn_test_001');
      expect(restored.routeName, 'Block 1 River Perimeter');
      expect(restored.assignedRangerId, 'ranger_yala_001');
      expect(restored.plannedDistanceKm, 7.5);
      expect(restored.estimatedDurationMinutes, 120);
      expect(restored.status, PatrolAssignmentStatus.assigned);
      expect(restored.checkpoints.length, 2);
      expect(restored.checkpoints[1].label, 'Water Hole');
    });

    test('copyWith updates specified fields', () {
      final assignment = PatrolAssignment(
        id: 'asgn_002',
        routeName: 'Ridge Patrol',
        area: 'Sector Bravo',
        assignedRangerId: 'ranger_yala_002',
        assignedDate: DateTime.utc(2026, 10, 14),
        plannedDistanceKm: 5.0,
        estimatedDurationMinutes: 90,
      );

      final updated = assignment.copyWith(
        status: PatrolAssignmentStatus.completed,
        plannedDistanceKm: 6.2,
      );

      expect(updated.id, 'asgn_002');
      expect(updated.status, PatrolAssignmentStatus.completed);
      expect(updated.plannedDistanceKm, 6.2);
      expect(updated.routeName, 'Ridge Patrol');
    });
  });

  group('PatrolAssignmentRepository', () {
    late InMemoryPatrolLocalStore localStore;
    late InMemoryPatrolAssignmentRepository repository;

    setUp(() async {
      localStore = InMemoryPatrolLocalStore();
      await localStore.initialize();
      repository = InMemoryPatrolAssignmentRepository(localStore: localStore);
    });

    test('saveAssignment stores assignment and queries by ranger UID', () async {
      final assignment1 = PatrolAssignment(
        id: 'asgn_ranger_1',
        routeName: 'Route Alpha',
        area: 'Sector 1',
        assignedRangerId: 'ranger_yala_001',
        assignedDate: DateTime.now(),
        plannedDistanceKm: 6.0,
        estimatedDurationMinutes: 90,
      );

      final assignment2 = PatrolAssignment(
        id: 'asgn_ranger_2',
        routeName: 'Route Beta',
        area: 'Sector 2',
        assignedRangerId: 'ranger_yala_002',
        assignedDate: DateTime.now(),
        plannedDistanceKm: 8.0,
        estimatedDurationMinutes: 120,
      );

      await repository.saveAssignment(assignment1);
      await repository.saveAssignment(assignment2);

      // Scoped query for ranger_yala_001
      final ranger1Assignments =
          await repository.getAssignmentsForRanger('ranger_yala_001');
      expect(ranger1Assignments.length, 1);
      expect(ranger1Assignments.first.id, 'asgn_ranger_1');

      // Scoped query for ranger_yala_002
      final ranger2Assignments =
          await repository.getAssignmentsForRanger('ranger_yala_002');
      expect(ranger2Assignments.length, 1);
      expect(ranger2Assignments.first.id, 'asgn_ranger_2');

      // Manager all assignments query
      final all = await repository.getAllAssignments();
      expect(all.length, 2);
    });

    test('updates assignment status', () async {
      final assignment = PatrolAssignment(
        id: 'asgn_progress_test',
        routeName: 'Waterway Track',
        area: 'Sector 3',
        assignedRangerId: 'ranger_yala_001',
        assignedDate: DateTime.now(),
        plannedDistanceKm: 4.5,
        estimatedDurationMinutes: 60,
        status: PatrolAssignmentStatus.assigned,
      );

      await repository.saveAssignment(assignment);
      await repository.updateAssignmentStatus(
        'asgn_progress_test',
        PatrolAssignmentStatus.inProgress,
      );

      final retrieved =
          await repository.getAssignmentById('asgn_progress_test');
      expect(retrieved, isNotNull);
      expect(retrieved!.status, PatrolAssignmentStatus.inProgress);
    });

    test('caches assignments in localStore for offline durability', () async {
      final assignment = PatrolAssignment(
        id: 'asgn_offline_cache',
        routeName: 'Offline Route',
        area: 'Remote Buffer Zone',
        assignedRangerId: 'ranger_yala_001',
        assignedDate: DateTime.now(),
        plannedDistanceKm: 10.0,
        estimatedDurationMinutes: 180,
      );

      await repository.saveAssignment(assignment);

      // Check that it was durably saved in localStore cache
      final cached = localStore.readCachedAssignments(rangerId: 'ranger_yala_001');
      expect(cached.length, 1);
      expect(cached.first.routeName, 'Offline Route');
    });
  });
}
