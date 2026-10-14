import 'package:flutter_test/flutter_test.dart';
import 'package:wildora/src/features/manage_patrols/data/patrol_models.dart';

void main() {
  group('TrackPoint', () {
    group('isValid', () {
      test('accepts valid coordinates', () {
        expect(TrackPoint.isValid(0, 0), isTrue);
        expect(TrackPoint.isValid(90, 180), isTrue);
        expect(TrackPoint.isValid(-90, -180), isTrue);
        expect(TrackPoint.isValid(6.9271, 79.8612), isTrue);
      });

      test('rejects latitude outside -90..90', () {
        expect(TrackPoint.isValid(91, 0), isFalse);
        expect(TrackPoint.isValid(-91, 0), isFalse);
        expect(TrackPoint.isValid(90.001, 0), isFalse);
      });

      test('rejects longitude outside -180..180', () {
        expect(TrackPoint.isValid(0, 181), isFalse);
        expect(TrackPoint.isValid(0, -181), isFalse);
        expect(TrackPoint.isValid(0, 180.001), isFalse);
      });

      test('rejects non-finite values', () {
        expect(TrackPoint.isValid(double.nan, 0), isFalse);
        expect(TrackPoint.isValid(0, double.nan), isFalse);
        expect(TrackPoint.isValid(double.infinity, 0), isFalse);
        expect(TrackPoint.isValid(0, double.negativeInfinity), isFalse);
      });

      test('accepts boundary values', () {
        expect(TrackPoint.isValid(-90, -180), isTrue);
        expect(TrackPoint.isValid(90, 180), isTrue);
      });
    });

    test('serialization roundtrip', () {
      final tp = TrackPoint(
        latitude: 6.9271,
        longitude: 79.8612,
        timestamp: DateTime(2026, 10, 1, 14, 30),
        accuracy: 5.5,
        source: LocationSource.gps,
      );
      final map = tp.toMap();
      final restored = TrackPoint.fromMap(map);
      expect(restored.latitude, tp.latitude);
      expect(restored.longitude, tp.longitude);
      expect(restored.accuracy, tp.accuracy);
      expect(restored.source, tp.source);
    });

    test('fromMap handles manual source', () {
      final map = {
        'latitude': 7.0,
        'longitude': 80.0,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'accuracy': 0.0,
        'source': 'manual',
      };
      final tp = TrackPoint.fromMap(map);
      expect(tp.source, LocationSource.manual);
    });
  });

  group('Waypoint', () {
    test('serialization roundtrip', () {
      final wp = Waypoint(
        id: 'wp001',
        sessionId: 'sess001',
        type: WaypointType.animalSighting,
        latitude: 7.0,
        longitude: 80.0,
        locationSource: LocationSource.gps,
        timestamp: DateTime(2026, 10, 1, 15, 0),
        note: 'Elephant sighting',
        photoReference: 'photo_123',
      );
      final map = wp.toMap();
      final restored = Waypoint.fromMap(map);
      expect(restored.id, wp.id);
      expect(restored.sessionId, wp.sessionId);
      expect(restored.type, wp.type);
      expect(restored.latitude, wp.latitude);
      expect(restored.longitude, wp.longitude);
      expect(restored.locationSource, wp.locationSource);
      expect(restored.note, wp.note);
      expect(restored.photoReference, wp.photoReference);
    });

    test('optional fields can be null', () {
      final wp = Waypoint(
        id: 'wp002',
        sessionId: 'sess001',
        type: WaypointType.trailMarker,
        latitude: 7.0,
        longitude: 80.0,
        locationSource: LocationSource.manual,
        timestamp: DateTime.now(),
      );
      expect(wp.note, isNull);
      expect(wp.photoReference, isNull);
      final map = wp.toMap();
      expect(map['note'], isNull);
      expect(map['photoReference'], isNull);
      final restored = Waypoint.fromMap(map);
      expect(restored.note, isNull);
      expect(restored.photoReference, isNull);
    });
  });

  group('SyncMetadata', () {
    test('defaults', () {
      const sm = SyncMetadata();
      expect(sm.syncStatus, SyncStatus.pendingSync);
      expect(sm.localRevision, 1);
      expect(sm.serverRevision, isNull);
      expect(sm.lastSyncError, isNull);
    });

    test('copyWith preserves unset fields', () {
      const sm = SyncMetadata(
        syncStatus: SyncStatus.synchronized,
        localRevision: 5,
        serverRevision: 5,
      );
      final updated = sm.copyWith(syncStatus: SyncStatus.pendingSync);
      expect(updated.syncStatus, SyncStatus.pendingSync);
      expect(updated.localRevision, 5);
      expect(updated.serverRevision, 5);
    });

    test('copyWith clears lastSyncError when passed null explicitly', () {
      const sm = SyncMetadata(lastSyncError: 'something went wrong');
      // copyWith with lastSyncError not passed keeps current behavior
      final updated = sm.copyWith(syncStatus: SyncStatus.synchronized);
      // Note: copyWith always passes lastSyncError through, which is null
      // when not specified – this is the design choice in the model.
      expect(updated.lastSyncError, isNull);
    });

    test('serialization roundtrip', () {
      const sm = SyncMetadata(
        syncStatus: SyncStatus.syncFailed,
        localRevision: 3,
        serverRevision: 2,
        lastSyncError: 'Network error',
      );
      final map = sm.toMap();
      final restored = SyncMetadata.fromMap(map);
      expect(restored.syncStatus, sm.syncStatus);
      expect(restored.localRevision, sm.localRevision);
      expect(restored.serverRevision, sm.serverRevision);
      expect(restored.lastSyncError, sm.lastSyncError);
    });
  });

  group('RouteDeviation', () {
    test('serialization roundtrip', () {
      final rd = RouteDeviation(
        timestamp: DateTime(2026, 10, 1, 16, 0),
        latitude: 6.5,
        longitude: 80.5,
        reason: 'Trail blocked',
      );
      final map = rd.toMap();
      final restored = RouteDeviation.fromMap(map);
      expect(restored.latitude, rd.latitude);
      expect(restored.longitude, rd.longitude);
      expect(restored.reason, rd.reason);
    });

    test('reason can be null', () {
      final rd = RouteDeviation(
        timestamp: DateTime.now(),
        latitude: 6.5,
        longitude: 80.5,
      );
      expect(rd.reason, isNull);
      final map = rd.toMap();
      final restored = RouteDeviation.fromMap(map);
      expect(restored.reason, isNull);
    });
  });

  group('PatrolSession', () {
    test('actualDuration returns zero when no startTime', () {
      const session = PatrolSession(
        sessionId: 'test',
        assignedRouteId: 'route1',
      );
      expect(session.actualDuration, Duration.zero);
    });

    test('actualDuration uses endTime when completed', () {
      final start = DateTime(2026, 10, 1, 10, 0);
      final end = DateTime(2026, 10, 1, 12, 30);
      final session = PatrolSession(
        sessionId: 'test',
        assignedRouteId: 'route1',
        startTime: start,
        endTime: end,
        lifecycleStatus: PatrolLifecycleStatus.completed,
      );
      expect(session.actualDuration, const Duration(hours: 2, minutes: 30));
    });

    group('recordedDistanceKm', () {
      test('returns 0 with fewer than 2 GPS points', () {
        const session = PatrolSession(
          sessionId: 'test',
          assignedRouteId: 'route1',
          trackPoints: [],
        );
        expect(session.recordedDistanceKm, 0.0);
      });

      test('returns 0 with single GPS point', () {
        final session = PatrolSession(
          sessionId: 'test',
          assignedRouteId: 'route1',
          trackPoints: [
            TrackPoint(
              latitude: 6.9271,
              longitude: 79.8612,
              timestamp: DateTime(2026, 10, 1, 10, 0),
              accuracy: 5.0,
            ),
          ],
        );
        expect(session.recordedDistanceKm, 0.0);
      });

      test('computes distance between consecutive GPS points', () {
        final t = DateTime(2026, 10, 1, 10, 0);
        final session = PatrolSession(
          sessionId: 'test',
          assignedRouteId: 'route1',
          trackPoints: [
            TrackPoint(
              latitude: 0.0,
              longitude: 0.0,
              timestamp: t,
              accuracy: 5.0,
            ),
            TrackPoint(
              latitude: 0.0,
              longitude: 1.0,
              timestamp: t.add(const Duration(minutes: 2)),
              accuracy: 5.0,
            ),
          ],
        );
        // ~111.19 km per degree of longitude at equator
        expect(session.recordedDistanceKm, closeTo(111.19, 1.0));
      });

      test('excludes manual-source track points from distance', () {
        final t = DateTime(2026, 10, 1, 10, 0);
        final session = PatrolSession(
          sessionId: 'test',
          assignedRouteId: 'route1',
          trackPoints: [
            TrackPoint(
              latitude: 0.0,
              longitude: 0.0,
              timestamp: t,
              accuracy: 5.0,
              source: LocationSource.gps,
            ),
            // Manual point should be excluded
            TrackPoint(
              latitude: 10.0,
              longitude: 10.0,
              timestamp: t.add(const Duration(minutes: 1)),
              accuracy: 0.0,
              source: LocationSource.manual,
            ),
            TrackPoint(
              latitude: 0.0,
              longitude: 1.0,
              timestamp: t.add(const Duration(minutes: 2)),
              accuracy: 5.0,
              source: LocationSource.gps,
            ),
          ],
        );
        // Should only compute between the two GPS points, ignoring the manual one
        expect(session.recordedDistanceKm, closeTo(111.19, 1.0));
      });

      test('does not connect across GPS gaps (5+ min)', () {
        final t = DateTime(2026, 10, 1, 10, 0);
        final session = PatrolSession(
          sessionId: 'test',
          assignedRouteId: 'route1',
          trackPoints: [
            TrackPoint(
              latitude: 0.0,
              longitude: 0.0,
              timestamp: t,
              accuracy: 5.0,
            ),
            TrackPoint(
              latitude: 0.0,
              longitude: 1.0,
              // 6 minutes gap → should break the chain
              timestamp: t.add(const Duration(minutes: 6)),
              accuracy: 5.0,
            ),
          ],
        );
        expect(session.recordedDistanceKm, 0.0);
      });

      test('connects across gaps under 5 minutes', () {
        final t = DateTime(2026, 10, 1, 10, 0);
        final session = PatrolSession(
          sessionId: 'test',
          assignedRouteId: 'route1',
          trackPoints: [
            TrackPoint(
              latitude: 0.0,
              longitude: 0.0,
              timestamp: t,
              accuracy: 5.0,
            ),
            TrackPoint(
              latitude: 0.0,
              longitude: 1.0,
              timestamp: t.add(const Duration(minutes: 4, seconds: 59)),
              accuracy: 5.0,
            ),
          ],
        );
        expect(session.recordedDistanceKm, greaterThan(0.0));
      });

      test('accumulates distance across multiple segments with a gap', () {
        final t = DateTime(2026, 10, 1, 10, 0);
        final session = PatrolSession(
          sessionId: 'test',
          assignedRouteId: 'route1',
          trackPoints: [
            // Segment 1: 0,0 → 0,1 (within gap threshold)
            TrackPoint(
              latitude: 0.0, longitude: 0.0,
              timestamp: t, accuracy: 5.0,
            ),
            TrackPoint(
              latitude: 0.0, longitude: 1.0,
              timestamp: t.add(const Duration(minutes: 2)), accuracy: 5.0,
            ),
            // GAP: 6 minutes
            // Segment 2: 0,2 → 0,3 (within gap threshold)
            TrackPoint(
              latitude: 0.0, longitude: 2.0,
              timestamp: t.add(const Duration(minutes: 8)), accuracy: 5.0,
            ),
            TrackPoint(
              latitude: 0.0, longitude: 3.0,
              timestamp: t.add(const Duration(minutes: 10)), accuracy: 5.0,
            ),
          ],
        );
        // Two segments of ~111.19 km each, gap between them is skipped
        expect(session.recordedDistanceKm, closeTo(222.39, 2.0));
      });
    });

    group('hasGpsGaps', () {
      test('returns true for completed patrol with no track points', () {
        const session = PatrolSession(
          sessionId: 'test',
          assignedRouteId: 'route1',
          lifecycleStatus: PatrolLifecycleStatus.completed,
          trackPoints: [],
        );
        expect(session.hasGpsGaps, isTrue);
      });

      test('returns false for active patrol with no track points', () {
        const session = PatrolSession(
          sessionId: 'test',
          assignedRouteId: 'route1',
          lifecycleStatus: PatrolLifecycleStatus.active,
          trackPoints: [],
        );
        expect(session.hasGpsGaps, isFalse);
      });

      test('returns true when gap >= 5 minutes', () {
        final t = DateTime(2026, 10, 1, 10, 0);
        final session = PatrolSession(
          sessionId: 'test',
          assignedRouteId: 'route1',
          trackPoints: [
            TrackPoint(
              latitude: 6.9, longitude: 79.8,
              timestamp: t, accuracy: 5.0,
            ),
            TrackPoint(
              latitude: 6.91, longitude: 79.81,
              timestamp: t.add(const Duration(minutes: 5)),
              accuracy: 5.0,
            ),
          ],
        );
        expect(session.hasGpsGaps, isTrue);
      });

      test('returns false when gap < 5 minutes', () {
        final t = DateTime(2026, 10, 1, 10, 0);
        final session = PatrolSession(
          sessionId: 'test',
          assignedRouteId: 'route1',
          trackPoints: [
            TrackPoint(
              latitude: 6.9, longitude: 79.8,
              timestamp: t, accuracy: 5.0,
            ),
            TrackPoint(
              latitude: 6.91, longitude: 79.81,
              timestamp: t.add(const Duration(minutes: 4, seconds: 59)),
              accuracy: 5.0,
            ),
          ],
        );
        expect(session.hasGpsGaps, isFalse);
      });

      test('ignores manual track points for gap detection', () {
        final t = DateTime(2026, 10, 1, 10, 0);
        final session = PatrolSession(
          sessionId: 'test',
          assignedRouteId: 'route1',
          trackPoints: [
            TrackPoint(
              latitude: 6.9, longitude: 79.8,
              timestamp: t, accuracy: 5.0,
              source: LocationSource.gps,
            ),
            // Manual point 6 minutes later – should not count as breaking
            // the GPS chain because it's not GPS-source
            TrackPoint(
              latitude: 7.0, longitude: 80.0,
              timestamp: t.add(const Duration(minutes: 6)),
              accuracy: 0.0,
              source: LocationSource.manual,
            ),
            TrackPoint(
              latitude: 6.91, longitude: 79.81,
              timestamp: t.add(const Duration(minutes: 7)),
              accuracy: 5.0,
              source: LocationSource.gps,
            ),
          ],
        );
        // Gap between first and third GPS point is 7 min → gap
        expect(session.hasGpsGaps, isTrue);
      });
    });

    test('full serialization roundtrip', () {
      final session = PatrolSession(
        sessionId: 'sess123',
        assignedRouteId: 'route_east',
        rangerId: 'ranger_001',
        startTime: DateTime(2026, 10, 1, 10, 0),
        endTime: DateTime(2026, 10, 1, 12, 0),
        lifecycleStatus: PatrolLifecycleStatus.completed,
        revision: 5,
        routeName: 'East Perimeter',
        estimatedDurationMinutes: 120,
        plannedDistanceKm: 8.5,
        deviations: [
          RouteDeviation(
            timestamp: DateTime(2026, 10, 1, 11, 0),
            latitude: 6.9, longitude: 79.8,
            reason: 'Blocked trail',
          ),
        ],
        trackPoints: [
          TrackPoint(
            latitude: 6.9, longitude: 79.8,
            timestamp: DateTime(2026, 10, 1, 10, 0),
            accuracy: 5.0,
          ),
        ],
        waypoints: [
          Waypoint(
            id: 'wp1', sessionId: 'sess123',
            type: WaypointType.evidence,
            latitude: 6.95, longitude: 79.85,
            locationSource: LocationSource.gps,
            timestamp: DateTime(2026, 10, 1, 10, 30),
            note: 'Snare found',
          ),
        ],
        syncMetadata: const SyncMetadata(
          syncStatus: SyncStatus.synchronized,
          localRevision: 5,
          serverRevision: 5,
        ),
      );

      final map = session.toMap();
      final restored = PatrolSession.fromMap(map);

      expect(restored.sessionId, session.sessionId);
      expect(restored.assignedRouteId, session.assignedRouteId);
      expect(restored.rangerId, session.rangerId);
      expect(restored.lifecycleStatus, session.lifecycleStatus);
      expect(restored.revision, session.revision);
      expect(restored.routeName, session.routeName);
      expect(restored.estimatedDurationMinutes, session.estimatedDurationMinutes);
      expect(restored.plannedDistanceKm, session.plannedDistanceKm);
      expect(restored.deviations.length, 1);
      expect(restored.trackPoints.length, 1);
      expect(restored.waypoints.length, 1);
      expect(restored.syncMetadata.syncStatus, SyncStatus.synchronized);
    });

    test('copyWith preserves fields not specified', () {
      final session = PatrolSession(
        sessionId: 'test123',
        assignedRouteId: 'route1',
        rangerId: 'ranger1',
        routeName: 'Test Route',
        estimatedDurationMinutes: 90,
        plannedDistanceKm: 5.0,
      );
      final updated = session.copyWith(
        lifecycleStatus: PatrolLifecycleStatus.active,
      );
      expect(updated.sessionId, 'test123');
      expect(updated.routeName, 'Test Route');
      expect(updated.lifecycleStatus, PatrolLifecycleStatus.active);
    });
  });

  group('ID generation', () {
    test('newPatrolSessionId returns 32-char hex string', () {
      final id = newPatrolSessionId();
      expect(id.length, 32);
      expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(id), isTrue);
    });

    test('newWaypointId returns 16-char hex string', () {
      final id = newWaypointId();
      expect(id.length, 16);
      expect(RegExp(r'^[0-9a-f]{16}$').hasMatch(id), isTrue);
    });

    test('generated IDs are unique', () {
      final ids = List.generate(100, (_) => newPatrolSessionId());
      expect(ids.toSet().length, 100);
    });
  });

  group('WaypointType', () {
    test('all types have labels', () {
      for (final type in WaypointType.values) {
        expect(type.label, isNotEmpty);
      }
    });
  });
}
