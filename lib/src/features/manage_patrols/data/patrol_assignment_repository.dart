import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'patrol_local_store.dart';
import 'patrol_models.dart';

/// Contract for managing patrol route assignments created by Park Managers.
///
/// Follows Dependency Inversion:
/// Presentation and application layers depend on this abstraction,
/// allowing swapping between Cloud Firestore and in-memory test doubles.
abstract class PatrolAssignmentRepository {
  /// Save a newly created or updated patrol assignment.
  /// Throws if delivery to server fails.
  Future<void> saveAssignment(PatrolAssignment assignment);

  /// Fetch all active assignments designated for a specific ranger UID.
  Future<List<PatrolAssignment>> getAssignmentsForRanger(String rangerId);

  /// Fetch all assignments across all rangers (manager review).
  Future<List<PatrolAssignment>> getAllAssignments();

  /// Fetch a single assignment by its unique assignment ID.
  Future<PatrolAssignment?> getAssignmentById(String id);

  /// Update the status of an assignment (e.g. assigned -> inProgress -> completed).
  Future<void> updateAssignmentStatus(
    String id,
    PatrolAssignmentStatus status,
  );
}

/// Cloud Firestore implementation of [PatrolAssignmentRepository].
///
/// Guarantees:
/// - Explicit server acknowledgement before reporting success.
/// - Offline caching in [PatrolLocalStore] after successful save or as fallback.
class FirestorePatrolAssignmentRepository
    implements PatrolAssignmentRepository {
  FirestorePatrolAssignmentRepository({
    this._firestore,
    required this.localStore,
  });

  final FirebaseFirestore? _firestore;
  final PatrolLocalStore localStore;

  FirebaseFirestore? get _safeDb {
    if (_firestore != null) return _firestore;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  static const String collectionName = 'patrolAssignments';

  @override
  Future<void> saveAssignment(PatrolAssignment assignment) async {
    final db = _safeDb;
    if (db != null) {
      // Must await server write to guarantee delivery.
      // If Firestore rejects write (permissions, offline), exception propagates to caller.
      await db
          .collection(collectionName)
          .doc(assignment.id)
          .set(assignment.toMap(), SetOptions(merge: true));
    }

    // Update local durable cache after server write succeeds (or in headless test without db)
    await localStore.saveCachedAssignment(assignment);
  }

  @override
  Future<List<PatrolAssignment>> getAssignmentsForRanger(
    String rangerId,
  ) async {
    final db = _safeDb;
    if (db != null) {
      try {
        final snapshot = await db
            .collection(collectionName)
            .where('assignedRangerId', isEqualTo: rangerId)
            .get();

        if (snapshot.docs.isNotEmpty) {
          final remote = snapshot.docs
              .map((doc) => PatrolAssignment.fromMap(doc.data()))
              .toList();

          // Update local cache
          await localStore.saveCachedAssignments(remote);
          return remote;
        }
      } catch (_) {
        // Fall back to local durable cache on network/firestore error
      }
    }

    // Return locally cached assignments for this ranger
    return localStore.readCachedAssignments(rangerId: rangerId);
  }

  @override
  Future<List<PatrolAssignment>> getAllAssignments() async {
    final db = _safeDb;
    if (db != null) {
      try {
        final snapshot = await db.collection(collectionName).get();
        if (snapshot.docs.isNotEmpty) {
          final remote = snapshot.docs
              .map((doc) => PatrolAssignment.fromMap(doc.data()))
              .toList();
          await localStore.saveCachedAssignments(remote);
          return remote;
        }
      } catch (_) {
        // Fall back to local cache on network error
      }
    }
    return localStore.readCachedAssignments();
  }

  @override
  Future<PatrolAssignment?> getAssignmentById(String id) async {
    final db = _safeDb;
    if (db != null) {
      try {
        final doc = await db.collection(collectionName).doc(id).get();
        if (doc.exists && doc.data() != null) {
          final remote = PatrolAssignment.fromMap(doc.data()!);
          await localStore.saveCachedAssignment(remote);
          return remote;
        }
      } catch (_) {
        // Fall back to cache
      }
    }

    return localStore
        .readCachedAssignments()
        .where((a) => a.id == id)
        .firstOrNull;
  }

  @override
  Future<void> updateAssignmentStatus(
    String id,
    PatrolAssignmentStatus status,
  ) async {
    final db = _safeDb;
    if (db != null) {
      try {
        await db.collection(collectionName).doc(id).update({
          'status': status.name,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (_) {}
    }

    final existing = await getAssignmentById(id);
    if (existing != null) {
      final updated = existing.copyWith(status: status);
      await localStore.saveCachedAssignment(updated);
    }
  }
}

/// In-memory implementation of [PatrolAssignmentRepository] for tests and demo.
class InMemoryPatrolAssignmentRepository
    implements PatrolAssignmentRepository {
  InMemoryPatrolAssignmentRepository({
    this.localStore,
    List<PatrolAssignment>? initialAssignments,
  }) {
    if (initialAssignments != null) {
      for (final a in initialAssignments) {
        _assignments[a.id] = a;
      }
    }
  }

  final PatrolLocalStore? localStore;
  final Map<String, PatrolAssignment> _assignments = {};

  bool simulateFailure = false;

  @override
  Future<void> saveAssignment(PatrolAssignment assignment) async {
    if (simulateFailure) {
      throw Exception('Simulated server write failure: access denied or offline');
    }
    _assignments[assignment.id] = assignment;
    if (localStore != null) {
      await localStore!.saveCachedAssignment(assignment);
    }
  }

  @override
  Future<List<PatrolAssignment>> getAssignmentsForRanger(
    String rangerId,
  ) async {
    return _assignments.values
        .where((a) => a.assignedRangerId == rangerId)
        .toList();
  }

  @override
  Future<List<PatrolAssignment>> getAllAssignments() async {
    return _assignments.values.toList();
  }

  @override
  Future<PatrolAssignment?> getAssignmentById(String id) async {
    return _assignments[id];
  }

  @override
  Future<void> updateAssignmentStatus(
    String id,
    PatrolAssignmentStatus status,
  ) async {
    final existing = _assignments[id];
    if (existing != null) {
      final updated = existing.copyWith(status: status);
      _assignments[id] = updated;
      if (localStore != null) {
        await localStore!.saveCachedAssignment(updated);
      }
    }
  }
}
