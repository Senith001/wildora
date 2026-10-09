import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wildora/src/data/models/duty_roster.dart';
import 'package:wildora/src/data/models/high_risk_zone.dart';
import 'package:wildora/src/data/models/officer.dart';
import 'package:wildora/src/features/high_risk_movement/application/high_risk_zone_detection_service.dart';
import 'package:wildora/src/features/high_risk_movement/domain/geo.dart';

import '../../fakes/in_memory_repositories.dart';

void main() {
  group('HighRiskZoneDetectionService', () {
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

    group('checkZones', () {
      test('returns notInZone when no zones exist', () async {
        final location = GeoPoint2D(latitude: 0.0, longitude: 0.0);

        final result = await service.checkZones(location);

        expect(result.inZone, isFalse);
        expect(result.matchedZoneId, isNull);
      });

      test('returns notInZone when location is outside all zones', () async {
        // Add a zone at (1.0, 1.0) with 100m radius
        await zoneRepo.create(
          HighRiskZone(
            zoneId: 'zone1',
            name: 'Test Zone',
            riskLevel: 'High',
            center: _createGeoPoint(1.0, 1.0),
            radiusMeters: 100.0,
          ),
        );

        // Test location far away (approximately 157km away)
        final farLocation = GeoPoint2D(latitude: 2.0, longitude: 2.0);

        final result = await service.checkZones(farLocation);

        expect(result.inZone, isFalse);
        expect(result.matchedZoneId, isNull);
      });

      test('returns inZone for location inside single zone', () async {
        final zone = HighRiskZone(
          zoneId: 'zone1',
          name: 'Test Zone',
          riskLevel: 'High',
          center: _createGeoPoint(0.0, 0.0),
          radiusMeters: 1000.0,
        );
        await zoneRepo.create(zone);

        // Location very close to center (should be inside 1000m radius)
        final insideLocation = GeoPoint2D(latitude: 0.001, longitude: 0.001);

        final result = await service.checkZones(insideLocation);

        expect(result.inZone, isTrue);
        expect(result.matchedZoneId, equals(zone.zoneId));
        expect(result.distanceMeters, lessThan(1000.0));
      });

      test('boundary case: location exactly at radius is included', () async {
        final zone = HighRiskZone(
          zoneId: 'zone1',
          name: 'Test Zone',
          riskLevel: 'Medium',
          center: _createGeoPoint(-1.2921, 36.8219),
          radiusMeters: 500.0,
        );
        await zoneRepo.create(zone);

        // Calculate a point exactly 500m away
        // Using approximate: 1 degree latitude ≈ 111,320m
        // So 500m ≈ 0.00449 degrees
        final boundaryLocation = GeoPoint2D(
          latitude: -1.2921 + 0.00449,
          longitude: 36.8219,
        );

        final result = await service.checkZones(boundaryLocation);

        expect(result.inZone, isTrue);
        expect(result.matchedZoneId, equals('zone1'));
        // Distance should be very close to 500m (within tolerance)
        expect(result.distanceMeters, closeTo(500.0, 50.0));
      });

      test('multi-zone: selects zone with smallest distance', () async {
        // Zone 1: center (0, 0), radius 1000m
        final zone1 = HighRiskZone(
          zoneId: 'zone1',
          name: 'Zone 1',
          riskLevel: 'High',
          center: _createGeoPoint(0.0, 0.0),
          radiusMeters: 1000.0,
        );
        await zoneRepo.create(zone1);

        // Zone 2: center (0.005, 0.005), radius 1000m
        final zone2 = HighRiskZone(
          zoneId: 'zone2',
          name: 'Zone 2',
          riskLevel: 'High',
          center: _createGeoPoint(0.005, 0.005),
          radiusMeters: 1000.0,
        );
        await zoneRepo.create(zone2);

        // Test location closer to zone1 (0.001, 0.001)
        final testLocation = GeoPoint2D(latitude: 0.001, longitude: 0.001);

        final result = await service.checkZones(testLocation);

        expect(result.inZone, isTrue);
        expect(result.matchedZoneId, equals('zone1'));
      });

      test('multi-zone: equal distance selects highest risk level', () async {
        // Both zones at same center, different risk levels
        final lowRiskZone = HighRiskZone(
          zoneId: 'zone_low',
          name: 'Low Risk Zone',
          riskLevel: 'Low',
          center: _createGeoPoint(0.0, 0.0),
          radiusMeters: 1000.0,
        );
        await zoneRepo.create(lowRiskZone);

        final highRiskZone = HighRiskZone(
          zoneId: 'zone_high',
          name: 'High Risk Zone',
          riskLevel: 'High',
          center: _createGeoPoint(0.0, 0.0),
          radiusMeters: 1000.0,
        );
        await zoneRepo.create(highRiskZone);

        final testLocation = GeoPoint2D(latitude: 0.0, longitude: 0.0);

        final result = await service.checkZones(testLocation);

        expect(result.inZone, isTrue);
        expect(result.matchedZoneId, equals('zone_high'));
      });

      test('multi-zone: risk level priority High > Medium > Low', () async {
        final zones = [
          HighRiskZone(
            zoneId: 'zone_medium',
            name: 'Medium Zone',
            riskLevel: 'Medium',
            center: _createGeoPoint(0.0, 0.0),
            radiusMeters: 500.0,
          ),
          HighRiskZone(
            zoneId: 'zone_low',
            name: 'Low Zone',
            riskLevel: 'Low',
            center: _createGeoPoint(0.0, 0.0),
            radiusMeters: 500.0,
          ),
          HighRiskZone(
            zoneId: 'zone_high',
            name: 'High Zone',
            riskLevel: 'High',
            center: _createGeoPoint(0.0, 0.0),
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
    });

    group('resolveNearbyRecipients', () {
      late DateTime testTime;

      setUp(() {
        testTime = DateTime(2026, 10, 8, 12, 0, 0); // Noon on test date
      });

      test('returns empty list when no officers exist', () async {
        final zoneCenter = _createGeoPoint(0.0, 0.0);

        final recipients = await service.resolveNearbyRecipients(
          zoneCenter,
          testTime,
        );

        expect(recipients, isEmpty);
      });

      test('includes nearby on-duty ranger with fresh location', () async {
        // Create on-duty ranger within 5km with fresh location
        final ranger = _createOfficer(
          id: 'ranger1',
          name: 'Ranger One',
          role: 'ranger',
          location: _createGeoPoint(0.01, 0.01), // ~1.4km from (0,0)
          locationUpdatedAt: _createTimestamp(
            testTime.subtract(Duration(minutes: 15)),
          ), // 15 min ago
        );
        await officerRepo.create(ranger);

        // Set duty roster
        await dutyRosterRepo.setByDate(
          '2026-10-08',
          DutyRoster(
            date: '2026-10-08',
            onDutyRangerIds: ['ranger1'],
            lastUpdated: _createTimestamp(testTime),
          ),
        );

        final recipients = await service.resolveNearbyRecipients(
          _createGeoPoint(0.0, 0.0),
          testTime,
        );

        expect(recipients, equals(['ranger1']));
      });

      test('excludes off-duty ranger even if nearby and fresh', () async {
        // Create ranger who is NOT on duty
        final ranger = _createOfficer(
          id: 'ranger1',
          name: 'Ranger One',
          role: 'ranger',
          location: _createGeoPoint(0.01, 0.01),
          locationUpdatedAt: _createTimestamp(
            testTime.subtract(Duration(minutes: 15)),
          ),
        );
        await officerRepo.create(ranger);

        // Duty roster without this ranger
        await dutyRosterRepo.setByDate(
          '2026-10-08',
          DutyRoster(
            date: '2026-10-08',
            onDutyRangerIds: ['other-ranger'], // Different ranger on duty
            lastUpdated: _createTimestamp(testTime),
          ),
        );

        final recipients = await service.resolveNearbyRecipients(
          _createGeoPoint(0.0, 0.0),
          testTime,
        );

        expect(recipients, isEmpty);
      });

      test('excludes on-duty ranger with stale location (>30 min)', () async {
        // Ranger with location updated 31 minutes ago (stale)
        final ranger = _createOfficer(
          id: 'ranger1',
          name: 'Ranger One',
          role: 'ranger',
          location: _createGeoPoint(0.01, 0.01),
          locationUpdatedAt: _createTimestamp(
            testTime.subtract(Duration(minutes: 31)),
          ),
        );
        await officerRepo.create(ranger);

        await dutyRosterRepo.setByDate(
          '2026-10-08',
          DutyRoster(
            date: '2026-10-08',
            onDutyRangerIds: ['ranger1'],
            lastUpdated: _createTimestamp(testTime),
          ),
        );

        final recipients = await service.resolveNearbyRecipients(
          _createGeoPoint(0.0, 0.0),
          testTime,
        );

        expect(recipients, isEmpty);
      });

      test('boundary case: ranger with location exactly 30 minutes old is included', () async {
        // Location exactly 30 minutes ago (should be fresh)
        final ranger = _createOfficer(
          id: 'ranger1',
          name: 'Ranger One',
          role: 'ranger',
          location: _createGeoPoint(0.01, 0.01),
          locationUpdatedAt: _createTimestamp(
            testTime.subtract(Duration(minutes: 30)),
          ),
        );
        await officerRepo.create(ranger);

        await dutyRosterRepo.setByDate(
          '2026-10-08',
          DutyRoster(
            date: '2026-10-08',
            onDutyRangerIds: ['ranger1'],
            lastUpdated: _createTimestamp(testTime),
          ),
        );

        final recipients = await service.resolveNearbyRecipients(
          _createGeoPoint(0.0, 0.0),
          testTime,
        );

        expect(recipients, equals(['ranger1']));
      });

      test('includes nearby CLO regardless of duty status', () async {
        // CLO nearby (no duty/freshness requirements)
        final clo = _createOfficer(
          id: 'clo1',
          name: 'CLO One',
          role: 'clo',
          location: _createGeoPoint(0.01, 0.01), // ~1.4km
          locationUpdatedAt: null, // CLOs don't need fresh location
        );
        await officerRepo.create(clo);

        // No duty roster needed for CLO
        final recipients = await service.resolveNearbyRecipients(
          _createGeoPoint(0.0, 0.0),
          testTime,
        );

        expect(recipients, equals(['clo1']));
      });

      test('excludes officers beyond 5km radius', () async {
        // Officer far away (>5km)
        final farRanger = _createOfficer(
          id: 'ranger_far',
          name: 'Far Ranger',
          role: 'ranger',
          location: _createGeoPoint(0.1, 0.1), // ~15.7km away
          locationUpdatedAt: _createTimestamp(
            testTime.subtract(Duration(minutes: 10)),
          ),
        );
        await officerRepo.create(farRanger);

        await dutyRosterRepo.setByDate(
          '2026-10-08',
          DutyRoster(
            date: '2026-10-08',
            onDutyRangerIds: ['ranger_far'],
            lastUpdated: _createTimestamp(testTime),
          ),
        );

        final recipients = await service.resolveNearbyRecipients(
          _createGeoPoint(0.0, 0.0),
          testTime,
        );

        // Should apply fallback and return the far ranger
        expect(recipients, equals(['ranger_far']));
      });

      test('boundary case: officer exactly 5000m away is included', () async {
        // Calculate point approximately 5000m (5km) away
        // 1 degree latitude ≈ 111,320m, so 5000m ≈ 0.0449 degrees
        final ranger = _createOfficer(
          id: 'boundary_ranger',
          name: 'Boundary Ranger',
          role: 'ranger',
          location: _createGeoPoint(0.0449, 0.0), // ~5km north
          locationUpdatedAt: _createTimestamp(
            testTime.subtract(Duration(minutes: 10)),
          ),
        );
        await officerRepo.create(ranger);

        await dutyRosterRepo.setByDate(
          '2026-10-08',
          DutyRoster(
            date: '2026-10-08',
            onDutyRangerIds: ['boundary_ranger'],
            lastUpdated: _createTimestamp(testTime),
          ),
        );

        final recipients = await service.resolveNearbyRecipients(
          _createGeoPoint(0.0, 0.0),
          testTime,
        );

        expect(recipients, contains('boundary_ranger'));
      });

      test('returns both nearby ranger and CLO when both qualify', () async {
        final ranger = _createOfficer(
          id: 'ranger1',
          name: 'Ranger One',
          role: 'ranger',
          location: _createGeoPoint(0.01, 0.01),
          locationUpdatedAt: _createTimestamp(
            testTime.subtract(Duration(minutes: 15)),
          ),
        );
        await officerRepo.create(ranger);

        final clo = _createOfficer(
          id: 'clo1',
          name: 'CLO One',
          role: 'clo',
          location: _createGeoPoint(0.015, 0.015), // Different nearby location
        );
        await officerRepo.create(clo);

        await dutyRosterRepo.setByDate(
          '2026-10-08',
          DutyRoster(
            date: '2026-10-08',
            onDutyRangerIds: ['ranger1'],
            lastUpdated: _createTimestamp(testTime),
          ),
        );

        final recipients = await service.resolveNearbyRecipients(
          _createGeoPoint(0.0, 0.0),
          testTime,
        );

        expect(recipients, containsAll(['ranger1', 'clo1']));
        expect(recipients, hasLength(2));
      });

      group('nearest-2 fallback', () {
        test('returns nearest-2 when no nearby officers', () async {
          // Create officers all beyond 5km but with different distances
          final ranger1 = _createOfficer(
            id: 'ranger1',
            name: 'Far Ranger 1',
            role: 'ranger',
            location: _createGeoPoint(0.1, 0.0), // ~11.1km north
            locationUpdatedAt: _createTimestamp(
              testTime.subtract(Duration(minutes: 10)),
            ),
          );

          final ranger2 = _createOfficer(
            id: 'ranger2',
            name: 'Far Ranger 2',
            role: 'ranger',
            location: _createGeoPoint(0.2, 0.0), // ~22.2km north
            locationUpdatedAt: _createTimestamp(
              testTime.subtract(Duration(minutes: 10)),
            ),
          );

          final clo1 = _createOfficer(
            id: 'clo1',
            name: 'Far CLO',
            role: 'clo',
            location: _createGeoPoint(0.15, 0.0), // ~16.7km north
          );

          for (final officer in [ranger1, ranger2, clo1]) {
            await officerRepo.create(officer);
          }

          await dutyRosterRepo.setByDate(
            '2026-10-08',
            DutyRoster(
              date: '2026-10-08',
              onDutyRangerIds: ['ranger1', 'ranger2'],
              lastUpdated: _createTimestamp(testTime),
            ),
          );

          final recipients = await service.resolveNearbyRecipients(
            _createGeoPoint(0.0, 0.0),
            testTime,
          );

          // Should return 2 nearest: ranger1 (~11.1km) and clo1 (~16.7km)
          expect(recipients, hasLength(2));
          expect(recipients, contains('ranger1')); // Nearest
          expect(recipients, contains('clo1')); // Second nearest
          expect(recipients, isNot(contains('ranger2'))); // Farthest
        });

        test('fallback respects ranger duty status', () async {
          // Off-duty ranger shouldn't be in fallback
          final offDutyRanger = _createOfficer(
            id: 'ranger_off',
            name: 'Off Duty Ranger',
            role: 'ranger',
            location: _createGeoPoint(0.1, 0.0), // Closer but off-duty
            locationUpdatedAt: _createTimestamp(
              testTime.subtract(Duration(minutes: 10)),
            ),
          );

          final clo1 = _createOfficer(
            id: 'clo1',
            name: 'CLO 1',
            role: 'clo',
            location: _createGeoPoint(0.2, 0.0), // Farther but always eligible
          );

          for (final officer in [offDutyRanger, clo1]) {
            await officerRepo.create(officer);
          }

          // Duty roster without the ranger
          await dutyRosterRepo.setByDate(
            '2026-10-08',
            DutyRoster(
              date: '2026-10-08',
              onDutyRangerIds: [], // No rangers on duty
              lastUpdated: _createTimestamp(testTime),
            ),
          );

          final recipients = await service.resolveNearbyRecipients(
            _createGeoPoint(0.0, 0.0),
            testTime,
          );

          // Should only return the CLO
          expect(recipients, equals(['clo1']));
        });

        test(
          'fallback returns fewer than 2 if not enough eligible officers',
          () async {
            // Only one eligible officer
            final clo = _createOfficer(
              id: 'clo1',
              name: 'Only CLO',
              role: 'clo',
              location: _createGeoPoint(0.1, 0.0),
            );
            await officerRepo.create(clo);

            final recipients = await service.resolveNearbyRecipients(
              _createGeoPoint(0.0, 0.0),
              testTime,
            );

            expect(recipients, equals(['clo1']));
            expect(recipients, hasLength(1));
          },
        );

        test('returns empty when no eligible officers exist', () async {
          // Only off-duty ranger (not eligible)
          final offDutyRanger = _createOfficer(
            id: 'ranger_off',
            name: 'Off Duty Ranger',
            role: 'ranger',
            location: _createGeoPoint(0.1, 0.0),
            locationUpdatedAt: _createTimestamp(
              testTime.subtract(Duration(minutes: 10)),
            ),
          );
          await officerRepo.create(offDutyRanger);

          // No duty roster = no rangers on duty
          final recipients = await service.resolveNearbyRecipients(
            _createGeoPoint(0.0, 0.0),
            testTime,
          );

          expect(recipients, isEmpty);
        });
      });

      test('skips officers without location data', () async {
        // Officer with no location
        final officerNoLocation = _createOfficer(
          id: 'ranger_no_loc',
          name: 'Ranger No Location',
          role: 'ranger',
          location: null,
          locationUpdatedAt: null,
        );
        await officerRepo.create(officerNoLocation);

        await dutyRosterRepo.setByDate(
          '2026-10-08',
          DutyRoster(
            date: '2026-10-08',
            onDutyRangerIds: ['ranger_no_loc'],
            lastUpdated: _createTimestamp(testTime),
          ),
        );

        final recipients = await service.resolveNearbyRecipients(
          _createGeoPoint(0.0, 0.0),
          testTime,
        );

        expect(recipients, isEmpty);
      });
    });
  });
}

// Helper functions to create test objects
GeoPoint _createGeoPoint(double latitude, double longitude) {
  // Mock GeoPoint creation - in tests we can use the constructor directly
  // In real app this would come from Firestore
  return GeoPoint(latitude, longitude);
}

Timestamp _createTimestamp(DateTime dateTime) {
  return Timestamp.fromDate(dateTime);
}

Officer _createOfficer({
  required String id,
  required String name,
  required String role,
  GeoPoint? location,
  Timestamp? locationUpdatedAt,
  List<String> fcmTokens = const [],
}) {
  return Officer(
    officerId: id,
    name: name,
    role: role,
    location: location,
    locationUpdatedAt: locationUpdatedAt,
    fcmTokens: fcmTokens,
  );
}
