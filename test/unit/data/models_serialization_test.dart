import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wildora/src/data/models/alert.dart';
import 'package:wildora/src/data/models/alert_recipient.dart';
import 'package:wildora/src/data/models/animal.dart';
import 'package:wildora/src/data/models/duty_roster.dart';
import 'package:wildora/src/data/models/high_risk_zone.dart';
import 'package:wildora/src/data/models/officer.dart';
import 'package:wildora/src/data/models/user_preferences.dart';

void main() {
  group('Model Serialization Tests', () {
    test('Animal toMap/fromMap round-trip', () {
      final timestamp = Timestamp.now();
      final original = Animal(
        animalId: 'elephant-01',
        species: 'Elephant',
        name: 'Jumbo',
        collarId: 'collar-123',
        currentLocation: AnimalLocation(
          latitude: -1.2921,
          longitude: 36.8219,
          timestamp: timestamp,
        ),
      );

      final map = original.toMap();
      final restored = Animal.fromMap('elephant-01', map);

      expect(restored.animalId, equals(original.animalId));
      expect(restored.species, equals(original.species));
      expect(restored.name, equals(original.name));
      expect(restored.collarId, equals(original.collarId));
      expect(
        restored.currentLocation!.latitude,
        equals(original.currentLocation!.latitude),
      );
      expect(
        restored.currentLocation!.longitude,
        equals(original.currentLocation!.longitude),
      );
      expect(
        restored.currentLocation!.timestamp,
        equals(original.currentLocation!.timestamp),
      );
    });

    test('Animal without currentLocation serializes correctly', () {
      final original = Animal(
        animalId: 'buffalo-11',
        species: 'Buffalo',
        name: 'Stampede',
        collarId: null, // Some animals don't have collars
      );

      final map = original.toMap();
      final restored = Animal.fromMap('buffalo-11', map);

      expect(restored.animalId, equals(original.animalId));
      expect(restored.species, equals(original.species));
      expect(restored.name, equals(original.name));
      expect(restored.collarId, isNull);
      expect(restored.currentLocation, isNull);
    });

    test('HighRiskZone toMap/fromMap round-trip', () {
      final original = HighRiskZone(
        zoneId: 'zone-01',
        name: 'Farmland Border',
        riskLevel: 'High',
        center: const GeoPoint(-1.2921, 36.8219),
        radiusMeters: 1000.0,
      );

      final map = original.toMap();
      final restored = HighRiskZone.fromMap('zone-01', map);

      expect(restored.zoneId, equals(original.zoneId));
      expect(restored.name, equals(original.name));
      expect(restored.riskLevel, equals(original.riskLevel));
      expect(restored.center, equals(original.center));
      expect(restored.radiusMeters, equals(original.radiusMeters));
    });

    test('Alert toMap/fromMap round-trip with response fields', () {
      final timestamp = Timestamp.now();
      final respondingAt = Timestamp.fromDate(
        DateTime.now().add(Duration(minutes: 5)),
      );

      final original = Alert(
        alertId: 'alert-01',
        type: 'high_risk_movement',
        timestamp: timestamp,
        status: 'active',
        responseStatus: 'responding',
        respondingOfficerId: 'officer-01',
        respondingOfficerName: 'Ranger John',
        respondingAt: respondingAt,
        animalId: 'elephant-01',
        zoneId: 'zone-01',
        location: const AlertLocation(latitude: -1.2921, longitude: 36.8219),
        animalName: 'Jumbo',
        locationLabel: 'Near Village Road',
      );

      final map = original.toMap();
      final restored = Alert.fromMap('alert-01', map);

      expect(restored.alertId, equals(original.alertId));
      expect(restored.type, equals(original.type));
      expect(restored.timestamp, equals(original.timestamp));
      expect(restored.status, equals(original.status));
      expect(restored.responseStatus, equals(original.responseStatus));
      expect(
        restored.respondingOfficerId,
        equals(original.respondingOfficerId),
      );
      expect(
        restored.respondingOfficerName,
        equals(original.respondingOfficerName),
      );
      expect(restored.respondingAt, equals(original.respondingAt));
      expect(restored.animalId, equals(original.animalId));
      expect(restored.zoneId, equals(original.zoneId));
      expect(restored.location.latitude, equals(original.location.latitude));
      expect(restored.location.longitude, equals(original.location.longitude));
      expect(restored.animalName, equals(original.animalName));
      expect(restored.locationLabel, equals(original.locationLabel));
    });

    test('Alert defaults responseStatus to unclaimed when missing', () {
      final map = {
        'type': 'high_risk_movement',
        'timestamp': Timestamp.now(),
        'status': 'active',
        'animalId': 'elephant-01',
        'zoneId': 'zone-01',
        'location': {'latitude': -1.2921, 'longitude': 36.8219},
        'animalName': 'Jumbo',
        // Missing responseStatus field
      };

      final restored = Alert.fromMap('alert-01', map);
      expect(restored.responseStatus, equals('unclaimed'));
      expect(restored.respondingOfficerId, isNull);
      expect(restored.respondingOfficerName, isNull);
      expect(restored.respondingAt, isNull);
    });

    test('AlertRecipient toMap/fromMap round-trip', () {
      final readAt = Timestamp.now();
      final original = AlertRecipient(
        officerId: 'officer-01',
        officerName: 'Ranger John',
        role: 'ranger',
        deliveryStatus: 'read',
        readAt: readAt,
        notifiedChannels: ['inApp', 'fcm'],
      );

      final map = original.toMap();
      final restored = AlertRecipient.fromMap('officer-01', map);

      expect(restored.officerId, equals(original.officerId));
      expect(restored.officerName, equals(original.officerName));
      expect(restored.role, equals(original.role));
      expect(restored.deliveryStatus, equals(original.deliveryStatus));
      expect(restored.readAt, equals(original.readAt));
      expect(restored.notifiedChannels, equals(original.notifiedChannels));
    });

    test('Officer toMap/fromMap round-trip', () {
      final locationUpdated = Timestamp.now();
      final original = Officer(
        officerId: 'officer-01',
        name: 'Ranger John',
        role: 'ranger',
        contactNo: '+254701234567',
        location: const GeoPoint(-1.2921, 36.8219),
        locationUpdatedAt: locationUpdated,
        fcmTokens: ['token1', 'token2'],
      );

      final map = original.toMap();
      final restored = Officer.fromMap('officer-01', map);

      expect(restored.officerId, equals(original.officerId));
      expect(restored.name, equals(original.name));
      expect(restored.role, equals(original.role));
      expect(restored.contactNo, equals(original.contactNo));
      expect(restored.location, equals(original.location));
      expect(restored.locationUpdatedAt, equals(original.locationUpdatedAt));
      expect(restored.fcmTokens, equals(original.fcmTokens));
    });

    test('Officer without optional fields serializes correctly', () {
      final original = Officer(
        officerId: 'officer-02',
        name: 'CLO Jane',
        role: 'clo',
        // No contactNo, location, locationUpdatedAt, or fcmTokens
      );

      final map = original.toMap();
      final restored = Officer.fromMap('officer-02', map);

      expect(restored.officerId, equals(original.officerId));
      expect(restored.name, equals(original.name));
      expect(restored.role, equals(original.role));
      expect(restored.contactNo, isNull);
      expect(restored.location, isNull);
      expect(restored.locationUpdatedAt, isNull);
      expect(restored.fcmTokens, isEmpty);
    });

    test('DutyRoster toMap/fromMap round-trip', () {
      final lastUpdated = Timestamp.now();
      final original = DutyRoster(
        date: '2024-01-15',
        onDutyRangerIds: ['officer-01', 'officer-03', 'officer-05'],
        lastUpdated: lastUpdated,
      );

      final map = original.toMap();
      final restored = DutyRoster.fromMap('2024-01-15', map);

      expect(restored.date, equals(original.date));
      expect(restored.onDutyRangerIds, equals(original.onDutyRangerIds));
      expect(restored.lastUpdated, equals(original.lastUpdated));
      expect(restored.isOnDuty('officer-01'), isTrue);
      expect(restored.isOnDuty('officer-02'), isFalse);
      expect(restored.isOnDuty('officer-03'), isTrue);
    });

    test('DutyRoster with empty ranger list serializes correctly', () {
      final lastUpdated = Timestamp.now();
      final original = DutyRoster(
        date: '2024-01-16',
        onDutyRangerIds: [], // No rangers on duty
        lastUpdated: lastUpdated,
      );

      final map = original.toMap();
      final restored = DutyRoster.fromMap('2024-01-16', map);

      expect(restored.date, equals(original.date));
      expect(restored.onDutyRangerIds, isEmpty);
      expect(restored.lastUpdated, equals(original.lastUpdated));
      expect(restored.isOnDuty('officer-01'), isFalse);
    });

    test('UserPreferences toMap/fromMap round-trip', () {
      final lastUpdated = Timestamp.now();
      final original = UserPreferences(
        userId: 'user-demo',
        themeMode: 'dark',
        lastUpdated: lastUpdated,
      );

      final map = original.toMap();
      final restored = UserPreferences.fromMap('user-demo', map);

      expect(restored.userId, equals(original.userId));
      expect(restored.themeMode, equals(original.themeMode));
      expect(restored.lastUpdated, equals(original.lastUpdated));
    });

    test('Alert copyWith updates specific fields', () {
      final original = Alert(
        alertId: 'alert-01',
        type: 'high_risk_movement',
        timestamp: Timestamp.now(),
        status: 'active',
        responseStatus: 'unclaimed',
        animalId: 'elephant-01',
        zoneId: 'zone-01',
        location: const AlertLocation(latitude: -1.2921, longitude: 36.8219),
        animalName: 'Jumbo',
      );

      final updated = original.copyWith(
        status: 'acknowledged',
        responseStatus: 'responding',
        respondingOfficerId: 'officer-01',
        respondingOfficerName: 'Ranger John',
      );

      expect(updated.alertId, equals(original.alertId)); // Unchanged
      expect(updated.animalName, equals(original.animalName)); // Unchanged
      expect(updated.status, equals('acknowledged')); // Changed
      expect(updated.responseStatus, equals('responding')); // Changed
      expect(updated.respondingOfficerId, equals('officer-01')); // Changed
      expect(updated.respondingOfficerName, equals('Ranger John')); // Changed
    });

    test('Officer copyWith updates location correctly', () {
      final original = Officer(
        officerId: 'officer-01',
        name: 'Ranger John',
        role: 'ranger',
        fcmTokens: ['token1'],
      );

      final newLocation = const GeoPoint(-1.2922, 36.8220);
      final newTimestamp = Timestamp.now();

      final updated = original.copyWith(
        location: newLocation,
        locationUpdatedAt: newTimestamp,
        fcmTokens: ['token1', 'token2'],
      );

      expect(updated.officerId, equals(original.officerId)); // Unchanged
      expect(updated.name, equals(original.name)); // Unchanged
      expect(updated.location, equals(newLocation)); // Changed
      expect(updated.locationUpdatedAt, equals(newTimestamp)); // Changed
      expect(updated.fcmTokens, equals(['token1', 'token2'])); // Changed
    });
  });
}
