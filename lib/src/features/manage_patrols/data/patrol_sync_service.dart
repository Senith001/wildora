import 'dart:async';

import 'patrol_models.dart';
import 'patrol_local_store.dart';

/// Synchronization service for uploading patrol sessions to a remote server.
///
/// IMPORTANT: This implementation is a **simulated mock**. There is no real
/// backend API integrated. In production, [syncSession] would POST/PUT the
/// session JSON to a REST endpoint or Firestore document and handle conflict
/// resolution based on revisions.
///
/// The mock simulates:
/// - A 1.5-second network delay.
/// - A configurable failure mode for testing retry/error flows.
/// - Revision acknowledgement logic (only marks synchronized when the server
///   revision matches the local revision at time of upload).
class PatrolSyncService {
  PatrolSyncService({required this.localStore, this.simulateFailure = false});

  final PatrolLocalStore localStore;

  /// Set to true to simulate sync failures for testing.
  bool simulateFailure;

  /// Attempt to synchronize a patrol session with the remote server.
  ///
  /// Returns the updated [PatrolSession] with sync metadata reflecting the
  /// outcome. Persists the result to local storage.
  ///
  /// Does NOT create duplicate remote records when retrying: uses the same
  /// sessionId as the idempotency key.
  ///
  /// If a stale server acknowledgement arrives (serverRevision < localRevision),
  /// the session remains in pendingSync.
  Future<PatrolSession> syncSession(PatrolSession session) async {
    try {
      // Simulate network delay
      await Future<void>.delayed(const Duration(milliseconds: 1500));

      if (simulateFailure) {
        throw Exception('Simulated sync failure: server unreachable');
      }

      // Simulate server response: server acknowledges the current local revision.
      final serverAcknowledgedRevision = session.syncMetadata.localRevision;

      // Guard against stale acknowledgements: only mark synchronized if the
      // server revision matches or exceeds the current local revision.
      final currentLocal = session.syncMetadata.localRevision;
      if (serverAcknowledgedRevision < currentLocal) {
        // Stale ack – local data has advanced beyond what was uploaded.
        final updated = session.copyWith(
          syncMetadata: session.syncMetadata.copyWith(
            syncStatus: SyncStatus.pendingSync,
            serverRevision: serverAcknowledgedRevision,
            lastSyncError: 'Server acknowledged an older revision '
                '($serverAcknowledgedRevision < $currentLocal). '
                'Local changes still pending.',
          ),
        );
        await localStore.saveSession(updated);
        return updated;
      }

      final updated = session.copyWith(
        syncMetadata: session.syncMetadata.copyWith(
          syncStatus: SyncStatus.synchronized,
          serverRevision: serverAcknowledgedRevision,
          lastSyncError: null,
        ),
      );
      await localStore.saveSession(updated);
      return updated;
    } catch (e) {
      final failed = session.copyWith(
        syncMetadata: session.syncMetadata.copyWith(
          syncStatus: SyncStatus.syncFailed,
          lastSyncError: e.toString(),
        ),
      );
      await localStore.saveSession(failed);
      return failed;
    }
  }
}
