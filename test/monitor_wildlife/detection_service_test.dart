// Monitor Wildlife and Respond to Risk Alerts — Detection Service suite.
//
// Exercises the REAL HighRiskZoneDetectionService against the shared in-memory
// fakes with a fixed injected `now`. Covers point-in-circle zone detection with
// tie-breaking, plus proximity-based recipient resolution with role/duty/
// freshness filters and the nearest-2 fallback.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wildora/src/data/models/duty_roster.dart';
import 'package:wildora/src/data/models/high_risk_zone.dart';
import 'package:wildora/src/data/models/officer.dart';
import 'package:wildora/src/features/high_risk_movement/application/high_risk_zone_detection_service.dart';
import 'package:wildora/src/features/high_risk_movement/domain/geo.dart';

import '../fakes/in_memory_repositories.dart';

void main() {
  late HighRiskZoneDetectionService service;
  late InMemoryOfficerRepository officerRepo;
  late InMemoryDutyRosterRepository dutyRosterRepo;
  late InMemoryHighRiskZoneRepository zoneRepo;

  // Fixed injected clock so freshness checks are fully deterministic.
  final now = DateTime(2026, 10, 8, 12, 0, 0);
  const todayString = '2026-10-08';

  setUp(() {
    officerRepo = InMemoryOfficerRepository();
    dutyRosterRepo = InMemoryDutyRosterRepository();
    zoneRepo = InMemoryHighRiskZoneRepository();

    service = HighRiskZoneDetectionService(
      officerRepository: officerRepo,
      dutyRosterRepository: dutyRosterRepo,
      zoneRepository: zoneRepo,
    );
  });

  // ---------------------------------------------------------------------------
  // checkZones: point-in-circle detection + tie-breaking
  // ---------------------------------------------------------------------------
  group('checkZones', () {
    test('returns notInZone when no zones exist at all', () async {
      final result = await service.checkZones(
        GeoPoint2D(latitude: 0.0, longitude: 0.0),
      );

      expect(result.inZone, isFalse);
      expect(result.matchedZoneId, isNull);
    });

    test('returns notInZone when location is outside every zone', () async {
      await zoneRepo.create(
        HighRiskZone(
          zoneId: 'zone1',
          name: 'Test Zone',
          riskLevel: 'High',
          center: GeoPoint(1.0, 1.0),
          radiusMeters: 100.0,
        ),
      );

      final result = await service.checkZones(
        GeoPoint2D(latitude: 2.0, longitude: 2.0), // ~157km away
      );

      expect(result.inZone, isFalse);
      expect(result.matchedZoneId, isNull);
    });

    test('returns inZone for a location inside a single zone', () async {
      final zone = HighRiskZone(
        zoneId: 'zone1',
        name: 'Test Zone',
        riskLevel: 'High',
        center: GeoPoint(0.0, 0.0),
        radiusMeters: 1000.0,
      );
      await zoneRepo.create(zone);

      final result = await service.checkZones(
        GeoPoint2D(latitude: 0.001, longitude: 0.001),
      );

      expect(result.inZone, isTrue);
      expect(result.matchedZoneId, equals('zone1'));
      expect(result.distanceMeters, lessThan(1000.0));
    });

    test('boundary: a location exactly at the radius is included', () async {
      final zone = HighRiskZone(
        zoneId: 'zone1',
        name: 'Test Zone',
        riskLevel: 'Medium',
        center: GeoPoint(-1.2921, 36.8219),
        radiusMeters: 500.0,
      );
      await zoneRepo.create(zone);

      // ~500m north (0.00449 deg latitude).
      final result = await service.checkZones(
        GeoPoint2D(latitude: -1.2921 + 0.00449, longitude: 36.8219),
      );

      expect(result.inZone, isTrue);
      expect(result.matchedZoneId, equals('zone1'));
      expect(result.distanceMeters, closeTo(500.0, 50.0));
    });

    test('multi-zone: the nearest zone wins', () async {
      await zoneRepo.create(
        HighRiskZone(
          zoneId: 'zone1',
          name: 'Zone 1',
          riskLevel: 'High',
          center: GeoPoint(0.0, 0.0),
          radiusMeters: 1000.0,
        ),
      );
      await zoneRepo.create(
        HighRiskZone(
          zoneId: 'zone2',
          name: 'Zone 2',
          riskLevel: 'High',
          center: GeoPoint(0.005, 0.005),
          radiusMeters: 1000.0,
        ),
      );

      final result = await service.checkZones(
        GeoPoint2D(latitude: 0.001, longitude: 0.001), // closer to zone1
      );

      expect(result.inZone, isTrue);
      expect(result.matchedZoneId, equals('zone1'));
    });

    test('multi-zone: equal distance picks the highest risk level', () async {
      await zoneRepo.create(
        HighRiskZone(
          zoneId: 'zone_low',
          name: 'Low Risk Zone',
          riskLevel: 'Low',
          center: GeoPoint(0.0, 0.0),
          radiusMeters: 1000.0,
        ),
      );
      await zoneRepo.create(
        HighRiskZone(
          zoneId: 'zone_high',
          name: 'High Risk Zone',
          riskLevel: 'High',
          center: GeoPoint(0.0, 0.0),
          radiusMeters: 1000.0,
        ),
      );

      final result = await service.checkZones(
        GeoPoint2D(latitude: 0.0, longitude: 0.0),
      );

      expect(result.inZone, isTrue);
      expect(result.matchedZoneId, equals('zone_high'));
    });

    test('multi-zone: risk priority is High > Medium > Low', () async {
      final zones = [
        HighRiskZone(
          zoneId: 'zone_medium',
          name: 'Medium Zone',
          riskLevel: 'Medium',
          center: GeoPoint(0.0, 0.0),
          radiusMeters: 500.0,
        ),
        HighRiskZone(
          zoneId: 'zone_low',
          name: 'Low Zone',
          riskLevel: 'Low',
          center: GeoPoint(0.0, 0.0),
          radiusMeters: 500.0,
        ),
        HighRiskZone(
          zoneId: 'zone_high',
          name: 'High Zone',
          riskLevel: 'High',
          center: GeoPoint(0.0, 0.0),
          radiusMeters: 500.0,
        ),
      ];
      for (final zone in zones) {
        await zoneRepo.create(zone);
      }

      final result = await service.checkZones(
        GeoPoint2D(latitude: 0.0, longitude: 0.0),
      );

      expect(result.matchedZoneId, equals('zone_high'));
    });

    test('distance is primary: a nearer Low beats a farther High', () async {
      await zoneRepo.create(
        HighRiskZone(
          zoneId: 'zone_near_low',
          name: 'Near Low Zone',
          riskLevel: 'Low',
          center: GeoPoint(0.0, 0.0),
          radiusMeters: 2000.0,
        ),
      );
      await zoneRepo.create(
        HighRiskZone(
          zoneId: 'zone_far_high',
          name: 'Far High Zone',
          riskLevel: 'High',
          center: GeoPoint(0.01, 0.0), // ~1113m away
          radiusMeters: 2000.0,
        ),
      );

      final result = await service.checkZones(
        GeoPoint2D(latitude: 0.0, longitude: 0.0),
      );

      expect(result.inZone, isTrue);
      expect(result.matchedZoneId, equals('zone_near_low'));
      expect(result.distanceMeters, closeTo(0.0, 1.0));
    });

    test('equal distance: a known risk beats unknown/"Severe"', () async {
      // Both share the exact center. 'Severe' maps to priority 0 (default).
      await zoneRepo.create(
        HighRiskZone(
          zoneId: 'zone_unknown',
          name: 'Unknown Risk Zone',
          riskLevel: 'Severe',
          center: GeoPoint(0.0, 0.0),
          radiusMeters: 1000.0,
        ),
      );
      await zoneRepo.create(
        HighRiskZone(
          zoneId: 'zone_known_low',
          name: 'Known Low Zone',
          riskLevel: 'Low',
          center: GeoPoint(0.0, 0.0),
          radiusMeters: 1000.0,
        ),
      );

      final result = await service.checkZones(
        GeoPoint2D(latitude: 0.0, longitude: 0.0),
      );

      expect(result.inZone, isTrue);
      expect(result.matchedZoneId, equals('zone_known_low'));
      expect(result.distanceMeters, closeTo(0.0, 1.0));
    });

    test('zero-radius zone matches only at the exact center', () async {
      await zoneRepo.create(
        HighRiskZone(
          zoneId: 'zone_point',
          name: 'Point Zone',
          riskLevel: 'High',
          center: GeoPoint(-1.2921, 36.8219),
          radiusMeters: 0.0,
        ),
      );

      final atCenter = await service.checkZones(
        GeoPoint2D(latitude: -1.2921, longitude: 36.8219),
      );

      expect(atCenter.inZone, isTrue);
      expect(atCenter.matchedZoneId, equals('zone_point'));
      expect(atCenter.distanceMeters, equals(0.0));
    });

    test('zero-radius zone does NOT match a few meters away', () async {
      await zoneRepo.create(
        HighRiskZone(
          zoneId: 'zone_point',
          name: 'Point Zone',
          riskLevel: 'High',
          center: GeoPoint(-1.2921, 36.8219),
          radiusMeters: 0.0,
        ),
      );

      // ~5.5m north of center.
      final nearby = await service.checkZones(
        GeoPoint2D(latitude: -1.2921 + 0.00005, longitude: 36.8219),
      );

      expect(nearby.inZone, isFalse);
      expect(nearby.matchedZoneId, isNull);
      expect(nearby.distanceMeters, isNull);
    });

    test('partial multi-zone containment: inside exactly one zone', () async {
      await zoneRepo.create(
        HighRiskZone(
          zoneId: 'zone_a',
          name: 'Zone A',
          riskLevel: 'High',
          center: GeoPoint(0.0, 0.0),
          radiusMeters: 500.0,
        ),
      );
      await zoneRepo.create(
        HighRiskZone(
          zoneId: 'zone_b',
          name: 'Zone B',
          riskLevel: 'High',
          center: GeoPoint(0.1, 0.0), // ~11.1km away
          radiusMeters: 500.0,
        ),
      );
      await zoneRepo.create(
        HighRiskZone(
          zoneId: 'zone_c',
          name: 'Zone C',
          riskLevel: 'High',
          center: GeoPoint(0.0, 0.1), // ~11.1km away
          radiusMeters: 500.0,
        ),
      );

      final result = await service.checkZones(
        GeoPoint2D(latitude: 0.0, longitude: 0.0),
      );

      expect(result.inZone, isTrue);
      expect(result.matchedZoneId, equals('zone_a'));
      expect(result.distanceMeters, closeTo(0.0, 1.0));
    });
  });

  // ---------------------------------------------------------------------------
  // resolveNearbyRecipients: proximity + role/duty/freshness + fallback
  // ---------------------------------------------------------------------------
  group('resolveNearbyRecipients', () {
    Officer officer({
      required String id,
      required String role,
      GeoPoint? location,
      Timestamp? locationUpdatedAt,
    }) {
      return Officer(
        officerId: id,
        name: 'Officer $id',
        role: role,
        location: location,
        locationUpdatedAt: locationUpdatedAt,
      );
    }

    Future<void> seedRoster(List<String> onDutyRangerIds) async {
      await dutyRosterRepo.setByDate(
        todayString,
        DutyRoster(
          date: todayString,
          onDutyRangerIds: onDutyRangerIds,
          lastUpdated: Timestamp.fromDate(now),
        ),
      );
    }

    test('returns empty when no officers exist', () async {
      final recipients = await service.resolveNearbyRecipients(
        GeoPoint(0.0, 0.0),
        now,
      );

      expect(recipients, isEmpty);
    });

    test('includes a nearby on-duty ranger with a fresh location', () async {
      await officerRepo.create(
        officer(
          id: 'ranger1',
          role: 'ranger',
          location: GeoPoint(0.01, 0.01), // ~1.4km
          locationUpdatedAt: Timestamp.fromDate(
            now.subtract(const Duration(minutes: 15)),
          ),
        ),
      );
      await seedRoster(['ranger1']);

      final recipients = await service.resolveNearbyRecipients(
        GeoPoint(0.0, 0.0),
        now,
      );

      expect(recipients, equals(['ranger1']));
    });

    test('excludes an off-duty ranger even if nearby and fresh', () async {
      await officerRepo.create(
        officer(
          id: 'ranger1',
          role: 'ranger',
          location: GeoPoint(0.01, 0.01),
          locationUpdatedAt: Timestamp.fromDate(
            now.subtract(const Duration(minutes: 15)),
          ),
        ),
      );
      await seedRoster(['other-ranger']);

      final recipients = await service.resolveNearbyRecipients(
        GeoPoint(0.0, 0.0),
        now,
      );

      expect(recipients, isEmpty);
    });

    test('excludes an on-duty ranger with a stale location (>30 min)', () async {
      await officerRepo.create(
        officer(
          id: 'ranger1',
          role: 'ranger',
          location: GeoPoint(0.01, 0.01),
          locationUpdatedAt: Timestamp.fromDate(
            now.subtract(const Duration(minutes: 31)),
          ),
        ),
      );
      await seedRoster(['ranger1']);

      final recipients = await service.resolveNearbyRecipients(
        GeoPoint(0.0, 0.0),
        now,
      );

      expect(recipients, isEmpty);
    });

    test('boundary: a location exactly 30 minutes old is still fresh', () async {
      await officerRepo.create(
        officer(
          id: 'ranger1',
          role: 'ranger',
          location: GeoPoint(0.01, 0.01),
          locationUpdatedAt: Timestamp.fromDate(
            now.subtract(const Duration(minutes: 30)),
          ),
        ),
      );
      await seedRoster(['ranger1']);

      final recipients = await service.resolveNearbyRecipients(
        GeoPoint(0.0, 0.0),
        now,
      );

      expect(recipients, equals(['ranger1']));
    });

    test('includes a nearby CLO regardless of duty/freshness', () async {
      await officerRepo.create(
        officer(
          id: 'clo1',
          role: 'clo',
          location: GeoPoint(0.01, 0.01),
          locationUpdatedAt: null, // CLOs need no freshness
        ),
      );
      // No duty roster needed for a CLO.

      final recipients = await service.resolveNearbyRecipients(
        GeoPoint(0.0, 0.0),
        now,
      );

      expect(recipients, equals(['clo1']));
    });

    test('a single far officer (>5km) is handled via fallback', () async {
      await officerRepo.create(
        officer(
          id: 'ranger_far',
          role: 'ranger',
          location: GeoPoint(0.1, 0.1), // ~15.7km away
          locationUpdatedAt: Timestamp.fromDate(
            now.subtract(const Duration(minutes: 10)),
          ),
        ),
      );
      await seedRoster(['ranger_far']);

      final recipients = await service.resolveNearbyRecipients(
        GeoPoint(0.0, 0.0),
        now,
      );

      // No nearby officer, so the nearest-eligible fallback returns it.
      expect(recipients, equals(['ranger_far']));
    });

    test('boundary: an officer exactly 5000m away is included', () async {
      await officerRepo.create(
        officer(
          id: 'boundary_ranger',
          role: 'ranger',
          location: GeoPoint(0.0449, 0.0), // ~5km north
          locationUpdatedAt: Timestamp.fromDate(
            now.subtract(const Duration(minutes: 10)),
          ),
        ),
      );
      await seedRoster(['boundary_ranger']);

      final recipients = await service.resolveNearbyRecipients(
        GeoPoint(0.0, 0.0),
        now,
      );

      expect(recipients, contains('boundary_ranger'));
    });

    test('returns both a nearby ranger and CLO when both qualify', () async {
      await officerRepo.create(
        officer(
          id: 'ranger1',
          role: 'ranger',
          location: GeoPoint(0.01, 0.01),
          locationUpdatedAt: Timestamp.fromDate(
            now.subtract(const Duration(minutes: 15)),
          ),
        ),
      );
      await officerRepo.create(
        officer(id: 'clo1', role: 'clo', location: GeoPoint(0.015, 0.015)),
      );
      await seedRoster(['ranger1']);

      final recipients = await service.resolveNearbyRecipients(
        GeoPoint(0.0, 0.0),
        now,
      );

      expect(recipients, containsAll(['ranger1', 'clo1']));
      expect(recipients, hasLength(2));
    });

    group('nearest-2 fallback', () {
      test('returns the 2 nearest eligible officers when none nearby', () async {
        await officerRepo.create(
          officer(
            id: 'ranger1',
            role: 'ranger',
            location: GeoPoint(0.1, 0.0), // ~11.1km
            locationUpdatedAt: Timestamp.fromDate(
              now.subtract(const Duration(minutes: 10)),
            ),
          ),
        );
        await officerRepo.create(
          officer(
            id: 'ranger2',
            role: 'ranger',
            location: GeoPoint(0.2, 0.0), // ~22.2km
            locationUpdatedAt: Timestamp.fromDate(
              now.subtract(const Duration(minutes: 10)),
            ),
          ),
        );
        await officerRepo.create(
          officer(id: 'clo1', role: 'clo', location: GeoPoint(0.15, 0.0)),
        );
        await seedRoster(['ranger1', 'ranger2']);

        final recipients = await service.resolveNearbyRecipients(
          GeoPoint(0.0, 0.0),
          now,
        );

        expect(recipients, hasLength(2));
        expect(recipients, contains('ranger1')); // nearest
        expect(recipients, contains('clo1')); // second nearest
        expect(recipients, isNot(contains('ranger2'))); // farthest dropped
      });

      test('fallback respects ranger duty status', () async {
        await officerRepo.create(
          officer(
            id: 'ranger_off',
            role: 'ranger',
            location: GeoPoint(0.1, 0.0), // closer but off-duty
            locationUpdatedAt: Timestamp.fromDate(
              now.subtract(const Duration(minutes: 10)),
            ),
          ),
        );
        await officerRepo.create(
          officer(id: 'clo1', role: 'clo', location: GeoPoint(0.2, 0.0)),
        );
        await seedRoster(const []); // no rangers on duty

        final recipients = await service.resolveNearbyRecipients(
          GeoPoint(0.0, 0.0),
          now,
        );

        expect(recipients, equals(['clo1']));
      });

      test('returns fewer than 2 when only one is eligible', () async {
        await officerRepo.create(
          officer(id: 'clo1', role: 'clo', location: GeoPoint(0.1, 0.0)),
        );

        final recipients = await service.resolveNearbyRecipients(
          GeoPoint(0.0, 0.0),
          now,
        );

        expect(recipients, equals(['clo1']));
        expect(recipients, hasLength(1));
      });

      test('returns empty when no officers are eligible', () async {
        await officerRepo.create(
          officer(
            id: 'ranger_off',
            role: 'ranger',
            location: GeoPoint(0.1, 0.0),
            locationUpdatedAt: Timestamp.fromDate(
              now.subtract(const Duration(minutes: 10)),
            ),
          ),
        );
        // No duty roster => no on-duty rangers => not eligible.

        final recipients = await service.resolveNearbyRecipients(
          GeoPoint(0.0, 0.0),
          now,
        );

        expect(recipients, isEmpty);
      });
    });

    test('skips officers with a null location', () async {
      await officerRepo.create(
        officer(
          id: 'ranger_no_loc',
          role: 'ranger',
          location: null,
          locationUpdatedAt: null,
        ),
      );
      await seedRoster(['ranger_no_loc']);

      final recipients = await service.resolveNearbyRecipients(
        GeoPoint(0.0, 0.0),
        now,
      );

      expect(recipients, isEmpty);
    });
  });
}
