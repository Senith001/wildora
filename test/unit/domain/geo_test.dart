import 'package:flutter_test/flutter_test.dart';

import 'package:wildora/src/features/high_risk_movement/domain/geo.dart';

void main() {
  group('GeoPoint2D', () {
    test('should create point with correct coordinates', () {
      const point = GeoPoint2D(latitude: -1.2921, longitude: 36.8219);

      expect(point.latitude, equals(-1.2921));
      expect(point.longitude, equals(36.8219));
    });

    test('should implement equality correctly', () {
      const point1 = GeoPoint2D(latitude: -1.2921, longitude: 36.8219);
      const point2 = GeoPoint2D(latitude: -1.2921, longitude: 36.8219);
      const point3 = GeoPoint2D(latitude: -1.2920, longitude: 36.8219);

      expect(point1, equals(point2));
      expect(point1, isNot(equals(point3)));
    });

    test('should have consistent hashCode', () {
      const point1 = GeoPoint2D(latitude: -1.2921, longitude: 36.8219);
      const point2 = GeoPoint2D(latitude: -1.2921, longitude: 36.8219);

      expect(point1.hashCode, equals(point2.hashCode));
    });

    test('should have readable toString', () {
      const point = GeoPoint2D(latitude: -1.2921, longitude: 36.8219);

      expect(point.toString(), equals('GeoPoint2D(-1.2921, 36.8219)'));
    });
  });

  group('haversineMeters', () {
    test('should return zero distance for identical points', () {
      const lat = -1.2921;
      const lon = 36.8219;

      final distance = haversineMeters(lat, lon, lat, lon);

      expect(distance, equals(0.0));
    });

    test('should calculate approximate equator degree distance', () {
      // At equator, 1 degree longitude ≈ 111.32 km
      final distance = haversineMeters(0, 0, 0, 1);

      // Should be approximately 111,320 meters (within 1% tolerance)
      expect(distance, closeTo(111320, 1113));
    });

    test('should calculate approximate equator latitude degree distance', () {
      // 1 degree latitude ≈ 111.32 km everywhere
      final distance = haversineMeters(0, 0, 1, 0);

      // Should be approximately 111,320 meters (within 1% tolerance)
      expect(distance, closeTo(111320, 1113));
    });

    test('should be symmetric', () {
      const lat1 = -1.2921;
      const lon1 = 36.8219;
      const lat2 = -1.3000;
      const lon2 = 36.8300;

      final distance1 = haversineMeters(lat1, lon1, lat2, lon2);
      final distance2 = haversineMeters(lat2, lon2, lat1, lon1);

      expect(distance1, equals(distance2));
    });

    test('should calculate known test distance accurately', () {
      // Distance from plan seed data:
      // ranger-amara at (-1.2900, 36.8200) to farmland-border center (-1.2921, 36.8219)
      // Expected: approximately 315m based on actual calculation
      final distance = haversineMeters(-1.2900, 36.8200, -1.2921, 36.8219);

      // Should be approximately 315 meters (within reasonable tolerance)
      expect(distance, greaterThan(300));
      expect(distance, lessThan(330));
    });

    test('should handle negative coordinates', () {
      // Southern hemisphere and negative longitude
      final distance = haversineMeters(-10, -20, -10.01, -20.01);

      expect(distance, greaterThan(0));
      expect(distance, lessThan(2000)); // Should be roughly 1.4km
    });
  });

  group('isWithinRadius', () {
    const center = GeoPoint2D(latitude: -1.2921, longitude: 36.8219);

    test('should return true for center point', () {
      final result = isWithinRadius(center, center, 1000);

      expect(result, isTrue);
    });

    test('should return true for point just inside radius', () {
      // Point very close to center (< 1 meter away)
      const nearPoint = GeoPoint2D(latitude: -1.292099, longitude: 36.821899);

      final result = isWithinRadius(nearPoint, center, 1000);

      expect(result, isTrue);
    });

    test('should return true for point exactly on radius boundary', () {
      // Create a point approximately 500m north of center
      // At this latitude, ~0.0045 degrees ≈ 500m
      const boundaryPoint = GeoPoint2D(latitude: -1.2876, longitude: 36.8219);

      final distance = haversineMeters(
        boundaryPoint.latitude,
        boundaryPoint.longitude,
        center.latitude,
        center.longitude,
      );

      // Verify our test point is approximately at the boundary (~500m)
      expect(distance, closeTo(500, 50));

      // Use radius that includes our test point (boundary is inclusive)
      final result = isWithinRadius(boundaryPoint, center, 501);

      expect(result, isTrue); // Point at ~500.4m should be within 501m radius
    });

    test('should return false for point just outside radius', () {
      // Point far from center (definitely > 1000m away)
      const farPoint = GeoPoint2D(latitude: -1.2800, longitude: 36.8300);

      final result = isWithinRadius(farPoint, center, 1000);

      expect(result, isFalse);
    });

    test('should handle large radius', () {
      // Point that would be outside small radius but inside large radius
      const distantPoint = GeoPoint2D(latitude: -1.2500, longitude: 36.7500);

      final resultSmall = isWithinRadius(distantPoint, center, 1000);
      final resultLarge = isWithinRadius(distantPoint, center, 100000);

      expect(resultSmall, isFalse);
      expect(resultLarge, isTrue);
    });

    test('should work with zero radius', () {
      final resultSame = isWithinRadius(center, center, 0);
      const nearbyPoint = GeoPoint2D(latitude: -1.2920, longitude: 36.8219);
      final resultNearby = isWithinRadius(nearbyPoint, center, 0);

      expect(resultSame, isTrue); // Same point is at distance 0
      expect(resultNearby, isFalse); // Any other point is > 0 distance
    });

    test('should match proximity filtering use case', () {
      // Test the 5km proximity radius from plan
      const zoneCenter = GeoPoint2D(latitude: -1.2921, longitude: 36.8219);

      // ranger-amara (should be included - near)
      const rangerAmara = GeoPoint2D(latitude: -1.2900, longitude: 36.8200);

      // ranger-kasun (should be excluded - far)
      const rangerKasun = GeoPoint2D(latitude: -1.2500, longitude: 36.7500);

      final amaraInRange = isWithinRadius(rangerAmara, zoneCenter, 5000);
      final kasunInRange = isWithinRadius(rangerKasun, zoneCenter, 5000);

      expect(amaraInRange, isTrue);
      expect(kasunInRange, isFalse);
    });
  });
}
