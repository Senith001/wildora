import 'package:flutter_test/flutter_test.dart';

import 'package:wildora/src/features/high_risk_movement/domain/zone_check_result.dart';
import 'package:wildora/src/core/config/detection_config.dart';

void main() {
  group('ZoneCheckResult', () {
    test('should create not-in-zone result correctly', () {
      const result = ZoneCheckResult.notInZone();

      expect(result.inZone, isFalse);
      expect(result.matchedZoneId, isNull);
      expect(result.distanceMeters, isNull);
    });

    test('should create in-zone result correctly', () {
      const result = ZoneCheckResult.inZone(
        zoneId: 'zone-farmland-border',
        distance: 150.5,
      );

      expect(result.inZone, isTrue);
      expect(result.matchedZoneId, equals('zone-farmland-border'));
      expect(result.distanceMeters, equals(150.5));
    });

    test('should implement equality correctly', () {
      const result1 = ZoneCheckResult.inZone(
        zoneId: 'zone-farmland-border',
        distance: 150.5,
      );
      const result2 = ZoneCheckResult.inZone(
        zoneId: 'zone-farmland-border',
        distance: 150.5,
      );
      const result3 = ZoneCheckResult.inZone(
        zoneId: 'zone-main-road',
        distance: 150.5,
      );
      const result4 = ZoneCheckResult.notInZone();
      const result5 = ZoneCheckResult.notInZone();

      expect(result1, equals(result2));
      expect(result1, isNot(equals(result3)));
      expect(result4, equals(result5));
      expect(result1, isNot(equals(result4)));
    });

    test('should have consistent hashCode', () {
      const result1 = ZoneCheckResult.inZone(
        zoneId: 'zone-farmland-border',
        distance: 150.5,
      );
      const result2 = ZoneCheckResult.inZone(
        zoneId: 'zone-farmland-border',
        distance: 150.5,
      );

      expect(result1.hashCode, equals(result2.hashCode));
    });

    test('should have readable toString for not-in-zone', () {
      const result = ZoneCheckResult.notInZone();

      expect(result.toString(), equals('ZoneCheckResult.notInZone()'));
    });

    test('should have readable toString for in-zone', () {
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

    test('should handle zero distance', () {
      const result = ZoneCheckResult.inZone(
        zoneId: 'zone-center',
        distance: 0.0,
      );

      expect(result.inZone, isTrue);
      expect(result.distanceMeters, equals(0.0));
      expect(result.toString(), contains('distance: 0.0m'));
    });
  });

  group('DetectionConfig', () {
    test('should have correct locked proximity radius', () {
      expect(DetectionConfig.notifyRadiusMeters, equals(5000.0));
    });

    test('should have correct locked location age threshold', () {
      expect(DetectionConfig.maxLocationAgeMinutes, equals(30));
    });

    test('should have correct nearest fallback count', () {
      expect(DetectionConfig.nearestFallbackCount, equals(2));
    });

    test('should be constants (compile-time)', () {
      // These should be compile-time constants
      const radius = DetectionConfig.notifyRadiusMeters;
      const age = DetectionConfig.maxLocationAgeMinutes;
      const fallback = DetectionConfig.nearestFallbackCount;

      expect(radius, equals(5000.0));
      expect(age, equals(30));
      expect(fallback, equals(2));
    });

    test('radius should match plan specification', () {
      // Plan specifies 5km (5000m) as the decided proximity radius
      expect(DetectionConfig.notifyRadiusMeters, equals(5000.0));
    });

    test('location age should match plan specification', () {
      // Plan specifies 30 minutes as the decided freshness threshold
      expect(DetectionConfig.maxLocationAgeMinutes, equals(30));
    });

    test('fallback count should match plan specification', () {
      // Plan specifies nearest-2 as the decided fallback approach
      expect(DetectionConfig.nearestFallbackCount, equals(2));
    });
  });
}
