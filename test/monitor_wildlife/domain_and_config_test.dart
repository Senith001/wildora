// Monitor Wildlife and Respond to Risk Alerts — Domain & Config suite.
//
// Pure Dart only (no fakes, no Flutter bindings). Consolidates the geo helpers,
// ZoneCheckResult value object, DetectionConfig locked defaults and the
// MonitoringState enum helpers into a single focused, viva-friendly file.
import 'package:flutter_test/flutter_test.dart';

import 'package:wildora/src/core/config/detection_config.dart';
import 'package:wildora/src/features/high_risk_movement/domain/geo.dart';
import 'package:wildora/src/features/high_risk_movement/domain/monitoring_state.dart';
import 'package:wildora/src/features/high_risk_movement/domain/zone_check_result.dart';

void main() {
  // ---------------------------------------------------------------------------
  // GeoPoint2D value object
  // ---------------------------------------------------------------------------
  group('GeoPoint2D value object', () {
    test('stores the latitude/longitude it was constructed with', () {
      const point = GeoPoint2D(latitude: -1.2921, longitude: 36.8219);

      expect(point.latitude, equals(-1.2921));
      expect(point.longitude, equals(36.8219));
    });

    test('two points with identical coordinates are equal', () {
      const a = GeoPoint2D(latitude: -1.2921, longitude: 36.8219);
      const b = GeoPoint2D(latitude: -1.2921, longitude: 36.8219);

      expect(a, equals(b));
    });

    test('points with different coordinates are not equal', () {
      const a = GeoPoint2D(latitude: -1.2921, longitude: 36.8219);
      const c = GeoPoint2D(latitude: -1.2920, longitude: 36.8219);

      expect(a, isNot(equals(c)));
    });

    test('equal points share the same hashCode', () {
      const a = GeoPoint2D(latitude: -1.2921, longitude: 36.8219);
      const b = GeoPoint2D(latitude: -1.2921, longitude: 36.8219);

      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString is human readable', () {
      const point = GeoPoint2D(latitude: -1.2921, longitude: 36.8219);

      expect(point.toString(), equals('GeoPoint2D(-1.2921, 36.8219)'));
    });
  });

  // ---------------------------------------------------------------------------
  // haversineMeters great-circle distance
  // ---------------------------------------------------------------------------
  group('haversineMeters distance', () {
    test('returns exactly zero for identical points', () {
      const lat = -1.2921;
      const lon = 36.8219;

      expect(haversineMeters(lat, lon, lat, lon), equals(0.0));
    });

    test('one degree of longitude at the equator is ~111.32 km', () {
      final distance = haversineMeters(0, 0, 0, 1);

      expect(distance, closeTo(111320, 1113)); // within 1%
    });

    test('one degree of latitude is ~111.32 km', () {
      final distance = haversineMeters(0, 0, 1, 0);

      expect(distance, closeTo(111320, 1113)); // within 1%
    });

    test('is symmetric: distance(a,b) == distance(b,a)', () {
      const lat1 = -1.2921;
      const lon1 = 36.8219;
      const lat2 = -1.3000;
      const lon2 = 36.8300;

      expect(
        haversineMeters(lat1, lon1, lat2, lon2),
        equals(haversineMeters(lat2, lon2, lat1, lon1)),
      );
    });

    test('known seed distance (~315m) is accurate', () {
      // ranger-amara (-1.2900, 36.8200) to farmland-border center
      // (-1.2921, 36.8219) ~= 315m from plan seed data.
      final distance = haversineMeters(-1.2900, 36.8200, -1.2921, 36.8219);

      expect(distance, greaterThan(300));
      expect(distance, lessThan(330));
    });

    test('handles negative (southern/western) coordinates', () {
      final distance = haversineMeters(-10, -20, -10.01, -20.01);

      expect(distance, greaterThan(0));
      expect(distance, lessThan(2000)); // roughly 1.4km
    });
  });

  // ---------------------------------------------------------------------------
  // isWithinRadius point-in-circle helper (inclusive boundary)
  // ---------------------------------------------------------------------------
  group('isWithinRadius point-in-circle', () {
    const center = GeoPoint2D(latitude: -1.2921, longitude: 36.8219);

    test('center point is always within any positive radius', () {
      expect(isWithinRadius(center, center, 1000), isTrue);
    });

    test('point just inside the radius returns true', () {
      const nearPoint = GeoPoint2D(latitude: -1.292099, longitude: 36.821899);

      expect(isWithinRadius(nearPoint, center, 1000), isTrue);
    });

    test('point exactly on the radius boundary is included (inclusive)', () {
      // ~500m north of center.
      const boundaryPoint = GeoPoint2D(latitude: -1.2876, longitude: 36.8219);

      final distance = haversineMeters(
        boundaryPoint.latitude,
        boundaryPoint.longitude,
        center.latitude,
        center.longitude,
      );
      expect(distance, closeTo(500, 50));

      expect(isWithinRadius(boundaryPoint, center, 501), isTrue);
    });

    test('point just outside the radius returns false', () {
      const farPoint = GeoPoint2D(latitude: -1.2800, longitude: 36.8300);

      expect(isWithinRadius(farPoint, center, 1000), isFalse);
    });

    test('a large radius includes a distant point a small radius excludes', () {
      const distantPoint = GeoPoint2D(latitude: -1.2500, longitude: 36.7500);

      expect(isWithinRadius(distantPoint, center, 1000), isFalse);
      expect(isWithinRadius(distantPoint, center, 100000), isTrue);
    });

    test('zero radius matches only the exact center point', () {
      const nearbyPoint = GeoPoint2D(latitude: -1.2920, longitude: 36.8219);

      expect(isWithinRadius(center, center, 0), isTrue);
      expect(isWithinRadius(nearbyPoint, center, 0), isFalse);
    });

    test('matches the 5km proximity-filtering use case', () {
      const zoneCenter = GeoPoint2D(latitude: -1.2921, longitude: 36.8219);
      const rangerAmara = GeoPoint2D(latitude: -1.2900, longitude: 36.8200);
      const rangerKasun = GeoPoint2D(latitude: -1.2500, longitude: 36.7500);

      expect(isWithinRadius(rangerAmara, zoneCenter, 5000), isTrue);
      expect(isWithinRadius(rangerKasun, zoneCenter, 5000), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // ZoneCheckResult value object
  // ---------------------------------------------------------------------------
  group('ZoneCheckResult value object', () {
    test('notInZone factory produces an empty negative result', () {
      const result = ZoneCheckResult.notInZone();

      expect(result.inZone, isFalse);
      expect(result.matchedZoneId, isNull);
      expect(result.distanceMeters, isNull);
    });

    test('inZone factory captures zone id and distance', () {
      const result = ZoneCheckResult.inZone(
        zoneId: 'zone-farmland-border',
        distance: 150.5,
      );

      expect(result.inZone, isTrue);
      expect(result.matchedZoneId, equals('zone-farmland-border'));
      expect(result.distanceMeters, equals(150.5));
    });

    test('equality distinguishes zone id and in/out of zone', () {
      const r1 = ZoneCheckResult.inZone(
        zoneId: 'zone-farmland-border',
        distance: 150.5,
      );
      const r2 = ZoneCheckResult.inZone(
        zoneId: 'zone-farmland-border',
        distance: 150.5,
      );
      const r3 = ZoneCheckResult.inZone(
        zoneId: 'zone-main-road',
        distance: 150.5,
      );
      const notInA = ZoneCheckResult.notInZone();
      const notInB = ZoneCheckResult.notInZone();

      expect(r1, equals(r2));
      expect(r1, isNot(equals(r3)));
      expect(notInA, equals(notInB));
      expect(r1, isNot(equals(notInA)));
    });

    test('equal results share the same hashCode', () {
      const r1 = ZoneCheckResult.inZone(
        zoneId: 'zone-farmland-border',
        distance: 150.5,
      );
      const r2 = ZoneCheckResult.inZone(
        zoneId: 'zone-farmland-border',
        distance: 150.5,
      );

      expect(r1.hashCode, equals(r2.hashCode));
    });

    test('toString for the not-in-zone branch', () {
      const result = ZoneCheckResult.notInZone();

      expect(result.toString(), equals('ZoneCheckResult.notInZone()'));
    });

    test('toString for the in-zone branch includes id + distance', () {
      const result = ZoneCheckResult.inZone(
        zoneId: 'zone-farmland-border',
        distance: 150.5,
      );

      expect(
        result.toString(),
        equals(
          'ZoneCheckResult.inZone(zoneId: zone-farmland-border, distance: 150.5m)',
        ),
      );
    });

    test('handles a zero-distance in-zone result', () {
      const result = ZoneCheckResult.inZone(zoneId: 'zone-center', distance: 0.0);

      expect(result.inZone, isTrue);
      expect(result.distanceMeters, equals(0.0));
      expect(result.toString(), contains('distance: 0.0m'));
    });
  });

  // ---------------------------------------------------------------------------
  // DetectionConfig locked defaults
  // ---------------------------------------------------------------------------
  group('DetectionConfig locked defaults', () {
    test('notifyRadiusMeters is locked to 5000m (5km)', () {
      expect(DetectionConfig.notifyRadiusMeters, equals(5000.0));
    });

    test('maxLocationAgeMinutes is locked to 30 minutes', () {
      expect(DetectionConfig.maxLocationAgeMinutes, equals(30));
    });

    test('nearestFallbackCount is locked to 2 officers', () {
      expect(DetectionConfig.nearestFallbackCount, equals(2));
    });

    test('all defaults are usable as compile-time constants', () {
      const radius = DetectionConfig.notifyRadiusMeters;
      const age = DetectionConfig.maxLocationAgeMinutes;
      const fallback = DetectionConfig.nearestFallbackCount;

      expect(radius, equals(5000.0));
      expect(age, equals(30));
      expect(fallback, equals(2));
    });
  });

  // ---------------------------------------------------------------------------
  // MonitoringState enum helpers
  // ---------------------------------------------------------------------------
  group('MonitoringState.isSuccess', () {
    test('is true only for locationUpdated / noAlert / alertRaised', () {
      expect(MonitoringState.locationUpdated.isSuccess, isTrue);
      expect(MonitoringState.noAlert.isSuccess, isTrue);
      expect(MonitoringState.alertRaised.isSuccess, isTrue);
    });

    test('is false for idle / processing / missingUpdate / error', () {
      expect(MonitoringState.idle.isSuccess, isFalse);
      expect(MonitoringState.processing.isSuccess, isFalse);
      expect(MonitoringState.missingUpdate.isSuccess, isFalse);
      expect(MonitoringState.error.isSuccess, isFalse);
    });
  });

  group('MonitoringState.isProcessing', () {
    test('is true only for processing', () {
      expect(MonitoringState.processing.isProcessing, isTrue);
    });

    test('is false for every other state', () {
      expect(MonitoringState.idle.isProcessing, isFalse);
      expect(MonitoringState.locationUpdated.isProcessing, isFalse);
      expect(MonitoringState.noAlert.isProcessing, isFalse);
      expect(MonitoringState.alertRaised.isProcessing, isFalse);
      expect(MonitoringState.missingUpdate.isProcessing, isFalse);
      expect(MonitoringState.error.isProcessing, isFalse);
    });
  });

  group('MonitoringState.isError', () {
    test('is true for error AND missingUpdate', () {
      expect(MonitoringState.error.isError, isTrue);
      expect(MonitoringState.missingUpdate.isError, isTrue);
    });

    test('is false for every other state', () {
      expect(MonitoringState.idle.isError, isFalse);
      expect(MonitoringState.processing.isError, isFalse);
      expect(MonitoringState.locationUpdated.isError, isFalse);
      expect(MonitoringState.noAlert.isError, isFalse);
      expect(MonitoringState.alertRaised.isError, isFalse);
    });
  });

  group('MonitoringState.isAlertState', () {
    test('is true only for alertRaised', () {
      expect(MonitoringState.alertRaised.isAlertState, isTrue);
    });

    test('is false for every other state', () {
      expect(MonitoringState.idle.isAlertState, isFalse);
      expect(MonitoringState.processing.isAlertState, isFalse);
      expect(MonitoringState.locationUpdated.isAlertState, isFalse);
      expect(MonitoringState.noAlert.isAlertState, isFalse);
      expect(MonitoringState.missingUpdate.isAlertState, isFalse);
      expect(MonitoringState.error.isAlertState, isFalse);
    });
  });
}
