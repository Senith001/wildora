import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'patrol_local_store.dart';
import 'patrol_models.dart';

/// Service responsible for synchronizing local patrol sessions with Cloud Firestore.
///
/// Follows Single Responsibility and Robust Offline Sync patterns:
/// - Idempotent upserts keyed strictly by [PatrolSession.sessionId].
/// - Real server write acknowledgement required before marking [SyncStatus.synchronized].
/// - Tracks local vs server revisions per session to prevent stale acknowledgements.
/// - Merges sync metadata onto the freshest local session record to prevent overwriting
///   newer points, waypoints, or deviations recorded during an in-flight upload.
/// - Retains all local data durably on network failure and allows queued retry.
/// - Manager coverage queries fetch real server records from the `patrolSessions` collection.
class PatrolSyncService {
  PatrolSyncService({
    required this.localStore,
    this.firestore,
    this.simulateFailure = false,
    this.remoteUpsert,
    this.remoteReader,
  });

  final PatrolLocalStore localStore;
  final FirebaseFirestore? firestore;

  /// Optional remote writer hook for unit testing and deterministic simulation.
  final Future<void> Function(String sessionId, Map<String, dynamic> data)?
      remoteUpsert;

  /// Optional remote reader hook for unit testing.
  final Future<List<PatrolSession>> Function()? remoteReader;

  /// Test flag to simulate network or server failures in automated test suites.
  bool simulateFailure;

  static const String collectionName = 'patrolSessions';

  FirebaseFirestore? get _safeDb {
    if (firestore != null) return firestore;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  /// Synchronize a patrol session to Cloud Firestore.
  ///
  /// Guarantees:
  /// - Only marks [SyncStatus.synchronized] upon real server confirmation.
  /// - Guards against stale acknowledgements if local writes occurred in-flight.
  /// - Never overwrites newer points/waypoints on failure.
  Future<PatrolSession> syncSession(PatrolSession session) async {
    // 1. Guard against simulation uploads
    if (session.syncMetadata.isSimulation) {
      final latest = localStore.readSessionById(session.sessionId) ?? session;
      final updated = latest.copyWith(
        syncMetadata: latest.syncMetadata.copyWith(
          syncStatus: SyncStatus.syncFailed,
          lastSyncError:
              'Simulated dev patrols are blocked from cloud upload.',
        ),
      );
      await localStore.saveSession(updated);
      return updated;
    }

    // 2. Handle simulated test failure
    if (simulateFailure) {
      final latest = localStore.readSessionById(session.sessionId) ?? session;
      final failed = latest.copyWith(
        syncMetadata: latest.syncMetadata.copyWith(
          syncStatus: SyncStatus.syncFailed,
          lastSyncError: 'Simulated sync failure: server unreachable',
        ),
      );
      await localStore.saveSession(failed);
      return failed;
    }

    final localRevisionAtUpload = session.syncMetadata.localRevision;

    try {
      // 3. Real Cloud Firestore Upsert (or injected remote writer)
      final payload = session.toMap();
      payload['serverRevision'] = localRevisionAtUpload;
      payload['syncedAt'] = DateTime.now().toUtc().toIso8601String();

      if (remoteUpsert != null) {
        await remoteUpsert!(session.sessionId, payload);
      } else {
        final db = _safeDb;
        if (db == null) {
          throw StateError(
              'Cloud Firestore is unavailable. Session remains safely cached on device.');
        }

        final docRef = db.collection(collectionName).doc(session.sessionId);
        // Write to Firestore with merge
        await docRef.set(payload, SetOptions(merge: true));
      }

      // 4. Stale acknowledgement check:
      // Re-read latest stored session strictly by its specific sessionId
      final latestStored =
          localStore.readSessionById(session.sessionId) ?? session;

      if (latestStored.syncMetadata.localRevision > localRevisionAtUpload) {
        // Local revision advanced while upload was in flight!
        // Preserve pendingSync with serverRevision acknowledged up to localRevisionAtUpload
        final pending = latestStored.copyWith(
          syncMetadata: latestStored.syncMetadata.copyWith(
            syncStatus: SyncStatus.pendingSync,
            serverRevision: localRevisionAtUpload,
            lastSyncError:
                'Newer local edits pending upload (local v${latestStored.syncMetadata.localRevision} > ack v$localRevisionAtUpload).',
          ),
        );
        await localStore.saveSession(pending);
        return pending;
      }

      // 5. Successful synchronization
      final syncedWaypoints = latestStored.waypoints
          .map((w) => w.copyWith(isSynchronized: true))
          .toList();
      final synced = latestStored.copyWith(
        waypoints: syncedWaypoints,
        syncMetadata: latestStored.syncMetadata.copyWith(
          syncStatus: SyncStatus.synchronized,
          serverRevision: localRevisionAtUpload,
          lastSyncError: null,
        ),
      );
      await localStore.saveSession(synced);
      return synced;
    } catch (e) {
      // 6. Preservation on failure:
      // Re-read latest local session so newer in-flight points are NEVER lost
      final latestStored =
          localStore.readSessionById(session.sessionId) ?? session;
      final failed = latestStored.copyWith(
        syncMetadata: latestStored.syncMetadata.copyWith(
          syncStatus: SyncStatus.syncFailed,
          lastSyncError: 'Sync error: $e',
        ),
      );
      await localStore.saveSession(failed);
      return failed;
    }
  }

  /// Retrieve all real synchronized patrol sessions across the park for manager review.
  /// Strictly loads remote server records from Cloud Firestore.
  Future<List<PatrolSession>> getSynchronizedPatrolSessions() async {
    if (remoteReader != null) {
      return await remoteReader!();
    }

    final db = _safeDb;
    if (db != null) {
      try {
        final snapshot = await db
            .collection(collectionName)
            .where('lifecycleStatus', isEqualTo: 'completed')
            .get();

        if (snapshot.docs.isNotEmpty) {
          return snapshot.docs
              .map((doc) => PatrolSession.fromMap(doc.data()))
              .toList();
        }
      } catch (e) {
        if (kDebugMode) {
          print('Firestore getSynchronizedPatrolSessions error: $e');
        }
        rethrow;
      }
    }

    return [];
  }
}
