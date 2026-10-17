import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wildora/src/data/models/high_risk_zone.dart';
import 'package:wildora/src/features/high_risk_movement/application/high_risk_zone_detection_service.dart';
import 'package:wildora/src/features/high_risk_movement/domain/geo.dart';

import '../fakes/in_memory_repositories.dart';

void main() {
  group('HighRiskZoneDetectionService additional checkZones cases', () {
    late HighRiskZoneDetectionService service;
    late InMemoryOfficerRepository officerRepo;
    late InMemoryDutyRosterRepository dutyRosterRepo;
    late InMemoryHighRiskZoneRepository zoneRepo;

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

    test(
      '(a) nearer Low-risk zone beats farther High-risk zone (distance primary)',
      () async {
        // Nearer zone (centered on the test point) is Low risk.
        final nearLow = HighRiskZone(
          zoneId: 'zone_near_low',
          name: 'Near Low Zone',
          riskLevel: 'Low',
          center: GeoPoint(0.0, 0.0),
          radiusMeters: 2000.0,
        );
        // Farther zone is High risk but its center is ~1.1km away.
        final farHigh = HighRiskZone(
          zoneId: 'zone_far_high',
          name: 'Far High Zone',
          riskLevel: 'High',
          center: GeoPoint(0.01, 0.0), // ~1113m north of origin
          radiusMeters: 2000.0,
        );
        await zoneRepo.create(nearLow);
        await zoneRepo.create(farHigh);

        // Test exactly at the near zone's center (distance 0 to nearLow).
        final result = await service.checkZones(
          GeoPoint2D(latitude: 0.0, longitude: 0.0),
        );

        expect(result.inZone, isTrue);
        // Nearer zone wins despite being lower risk.
        expect(result.matchedZoneId, equals('zone_near_low'));
        expect(result.distanceMeters, closeTo(0.0, 1.0));
      },
    );

    test(
      '(b) equal-distance tie-break: known risk beats unknown/invalid riskLevel',
      () async {
        // Both zones share the exact same center => equal distance.
        // 'Severe' is not High/Medium/Low, so _riskLevelPriority returns 0.
        final unknownRisk = HighRiskZone(
          zoneId: 'zone_unknown',
          name: 'Unknown Risk Zone',
          riskLevel: 'Severe', // priority 0 (default branch)
          center: GeoPoint(0.0, 0.0),
          radiusMeters: 1000.0,
        );
        final knownRisk = HighRiskZone(
          zoneId: 'zone_known_low',
          name: 'Known Low Zone',
          riskLevel: 'Low', // priority 1 > 0
          center: GeoPoint(0.0, 0.0),
          radiusMeters: 1000.0,
        );
        await zoneRepo.create(unknownRisk);
        await zoneRepo.create(knownRisk);

        final result = await service.checkZones(
          GeoPoint2D(latitude: 0.0, longitude: 0.0),
        );

        expect(result.inZone, isTrue);
        // Known-risk zone wins the equal-distance tie.
        expect(result.matchedZoneId, equals('zone_known_low'));
        expect(result.distanceMeters, closeTo(0.0, 1.0));
      },
    );

    test('(c) zero-radius zone: center matches (distance 0 <= 0)', () async {
      final pointZone = HighRiskZone(
        zoneId: 'zone_point',
        name: 'Point Zone',
        riskLevel: 'High',
        center: GeoPoint(-1.2921, 36.8219),
        radiusMeters: 0.0,
      );
      await zoneRepo.create(pointZone);

      final atCenter = await service.checkZones(
        GeoPoint2D(latitude: -1.2921, longitude: 36.8219),
      );

      expect(atCenter.inZone, isTrue);
      expect(atCenter.matchedZoneId, equals('zone_point'));
      expect(atCenter.distanceMeters, equals(0.0));
    });

    test('(c) zero-radius zone: a few meters away does NOT match', () async {
      final pointZone = HighRiskZone(
        zoneId: 'zone_point',
        name: 'Point Zone',
        riskLevel: 'High',
        center: GeoPoint(-1.2921, 36.8219),
        radiusMeters: 0.0,
      );
      await zoneRepo.create(pointZone);

      // ~0.00005 deg latitude ≈ 5.5m north of center => distance > 0.
      final nearby = await service.checkZones(
        GeoPoint2D(latitude: -1.2921 + 0.00005, longitude: 36.8219),
      );

      expect(nearby.inZone, isFalse);
      expect(nearby.matchedZoneId, isNull);
      expect(nearby.distanceMeters, isNull);
    });

    test(
      '(d) partial multi-zone containment: point inside exactly one zone',
      () async {
        // Zone A contains the test point (small radius centered on it).
        final zoneA = HighRiskZone(
          zoneId: 'zone_a',
          name: 'Zone A',
          riskLevel: 'High',
          center: GeoPoint(0.0, 0.0),
          radiusMeters: 500.0,
        );
        // Zone B far to the north (~11.1km), point not inside.
        final zoneB = HighRiskZone(
          zoneId: 'zone_b',
          name: 'Zone B',
          riskLevel: 'High',
          center: GeoPoint(0.1, 0.0),
          radiusMeters: 500.0,
        );
        // Zone C far to the east (~11.1km), point not inside.
        final zoneC = HighRiskZone(
          zoneId: 'zone_c',
          name: 'Zone C',
          riskLevel: 'High',
          center: GeoPoint(0.0, 0.1),
          radiusMeters: 500.0,
        );
        await zoneRepo.create(zoneA);
        await zoneRepo.create(zoneB);
        await zoneRepo.create(zoneC);

        final result = await service.checkZones(
          GeoPoint2D(latitude: 0.0, longitude: 0.0),
        );

        expect(result.inZone, isTrue);
        expect(result.matchedZoneId, equals('zone_a'));
        expect(result.distanceMeters, closeTo(0.0, 1.0));
      },
    );
  });
}
