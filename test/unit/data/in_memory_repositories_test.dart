import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/in_memory_repositories.dart';

import 'package:wildora/src/data/models/animal.dart';
import 'package:wildora/src/data/models/alert.dart';
import 'package:wildora/src/data/models/alert_recipient.dart';
import 'package:wildora/src/data/models/duty_roster.dart';
import 'package:wildora/src/data/models/high_risk_zone.dart';
import 'package:wildora/src/data/models/officer.dart';
import 'package:wildora/src/data/models/user_preferences.dart';

void main() {
  group('InMemoryAnimalRepository', () {
    late InMemoryAnimalRepository repository;

    setUp(() {
      repository = InMemoryAnimalRepository();
    });

    test('returns null for non-existent animal', () async {
      final result = await repository.getById('non-existent');
      expect(result, isNull);
    });

    test('returns seeded animal by ID', () async {
      final animal = Animal(
        animalId: 'elephant-01',
        species: 'Elephant',
        name: 'Jumbo',
        collarId: 'collar-123',
      );

      repository.seed([animal]);

      final result = await repository.getById('elephant-01');
      expect(result, isNotNull);
      expect(result!.name, equals('Jumbo'));
      expect(result.species, equals('Elephant'));
    });

    test('updates current location', () async {
      final animal = Animal(
        animalId: 'elephant-01',
        species: 'Elephant',
        name: 'Jumbo',
        collarId: 'collar-123',
      );

      repository.seed([animal]);

      final newLocation = AnimalLocation(
        latitude: -1.2921,
        longitude: 36.8219,
        timestamp: Timestamp.now(),
      );

      await repository.updateCurrentLocation('elephant-01', newLocation);

      final result = await repository.getById('elephant-01');
      expect(result!.currentLocation, isNotNull);
      expect(result.currentLocation!.latitude, equals(-1.2921));
      expect(result.currentLocation!.longitude, equals(36.8219));
    });

    test('throws exception when updating non-existent animal', () async {
      final location = AnimalLocation(
        latitude: -1.2921,
        longitude: 36.8219,
        timestamp: Timestamp.now(),
      );

      expect(
        () => repository.updateCurrentLocation('non-existent', location),
        throwsException,
      );
    });

    test('returns all animals', () async {
      final animals = [
        Animal(animalId: 'elephant-01', species: 'Elephant', name: 'Jumbo'),
        Animal(animalId: 'lion-01', species: 'Lion', name: 'Simba'),
      ];

      repository.seed(animals);

      final result = await repository.getAll();
      expect(result.length, equals(2));
      expect(result.map((a) => a.name), containsAll(['Jumbo', 'Simba']));
    });
  });

  group('InMemoryHighRiskZoneRepository', () {
    late InMemoryHighRiskZoneRepository repository;

    setUp(() {
      repository = InMemoryHighRiskZoneRepository();
    });

    test('returns all seeded zones', () async {
      final zones = [
        HighRiskZone(
          zoneId: 'zone-01',
          name: 'Farmland Border',
          riskLevel: 'High',
          center: const GeoPoint(-1.2921, 36.8219),
          radiusMeters: 1000,
        ),
        HighRiskZone(
          zoneId: 'zone-02',
          name: 'Road Crossing',
          riskLevel: 'Medium',
          center: const GeoPoint(-1.2922, 36.8220),
          radiusMeters: 500,
        ),
      ];

      repository.seed(zones);

      final result = await repository.getAll();
      expect(result.length, equals(2));
      expect(
        result.map((z) => z.name),
        containsAll(['Farmland Border', 'Road Crossing']),
      );
    });

    test('returns zone by ID', () async {
      final zone = HighRiskZone(
        zoneId: 'zone-01',
        name: 'Farmland Border',
        riskLevel: 'High',
        center: const GeoPoint(-1.2921, 36.8219),
        radiusMeters: 1000,
      );

      repository.seed([zone]);

      final result = await repository.getById('zone-01');
      expect(result, isNotNull);
      expect(result!.name, equals('Farmland Border'));
      expect(result.riskLevel, equals('High'));
    });

    test('returns null for non-existent zone', () async {
      final result = await repository.getById('non-existent');
      expect(result, isNull);
    });
  });

  group('InMemoryAlertRepository', () {
    late InMemoryAlertRepository repository;

    setUp(() {
      repository = InMemoryAlertRepository();
    });

    tearDown(() {
      repository.dispose();
    });

    test('creates alert and returns generated ID', () async {
      final alert = Alert(
        alertId: 'temp-id',
        type: 'high_risk_movement',
        timestamp: Timestamp.now(),
        status: 'active',
        responseStatus: 'unclaimed',
        animalId: 'elephant-01',
        zoneId: 'zone-01',
        location: const AlertLocation(latitude: -1.2921, longitude: 36.8219),
        animalName: 'Jumbo',
      );

      final alertId = await repository.create(alert);
      expect(alertId, isNotEmpty);
      expect(alertId, startsWith('alert_'));

      final retrieved = await repository.getById(alertId);
      expect(retrieved, isNotNull);
      expect(retrieved!.animalName, equals('Jumbo'));
    });

    test('atomic claim response succeeds when unclaimed', () async {
      final alert = Alert(
        alertId: 'temp-id',
        type: 'high_risk_movement',
        timestamp: Timestamp.now(),
        status: 'active',
        responseStatus: 'unclaimed',
        animalId: 'elephant-01',
        zoneId: 'zone-01',
        location: const AlertLocation(latitude: -1.2921, longitude: 36.8219),
        animalName: 'Jumbo',
      );

      final alertId = await repository.create(alert);

      final success = await repository.claimResponse(
        alertId,
        'officer-01',
        'Ranger John',
      );
      expect(success, isTrue);

      final updatedAlert = await repository.getById(alertId);
      expect(updatedAlert!.responseStatus, equals('responding'));
      expect(updatedAlert.respondingOfficerId, equals('officer-01'));
      expect(updatedAlert.respondingOfficerName, equals('Ranger John'));
      expect(updatedAlert.respondingAt, isNotNull);
    });

    test('atomic claim response fails when already claimed', () async {
      final alert = Alert(
        alertId: 'temp-id',
        type: 'high_risk_movement',
        timestamp: Timestamp.now(),
        status: 'active',
        responseStatus: 'unclaimed',
        animalId: 'elephant-01',
        zoneId: 'zone-01',
        location: const AlertLocation(latitude: -1.2921, longitude: 36.8219),
        animalName: 'Jumbo',
      );

      final alertId = await repository.create(alert);

      // First claim should succeed
      final firstClaim = await repository.claimResponse(
        alertId,
        'officer-01',
        'Ranger John',
      );
      expect(firstClaim, isTrue);

      // Second claim should fail
      final secondClaim = await repository.claimResponse(
        alertId,
        'officer-02',
        'Ranger Jane',
      );
      expect(secondClaim, isFalse);

      // Alert should still be claimed by first officer
      final updatedAlert = await repository.getById(alertId);
      expect(updatedAlert!.respondingOfficerId, equals('officer-01'));
    });

    test('streams active alerts in descending timestamp order', () async {
      final alerts = [
        Alert(
          alertId: 'alert-1',
          type: 'high_risk_movement',
          timestamp: Timestamp.fromDate(DateTime(2024, 1, 1)),
          status: 'active',
          responseStatus: 'unclaimed',
          animalId: 'elephant-01',
          zoneId: 'zone-01',
          location: const AlertLocation(latitude: -1.2921, longitude: 36.8219),
          animalName: 'Jumbo',
        ),
        Alert(
          alertId: 'alert-2',
          type: 'high_risk_movement',
          timestamp: Timestamp.fromDate(DateTime(2024, 1, 2)),
          status: 'acknowledged',
          responseStatus: 'unclaimed',
          animalId: 'lion-01',
          zoneId: 'zone-02',
          location: const AlertLocation(latitude: -1.2922, longitude: 36.8220),
          animalName: 'Simba',
        ),
        Alert(
          alertId: 'alert-3',
          type: 'high_risk_movement',
          timestamp: Timestamp.fromDate(DateTime(2024, 1, 3)),
          status: 'active',
          responseStatus: 'unclaimed',
          animalId: 'buffalo-01',
          zoneId: 'zone-01',
          location: const AlertLocation(latitude: -1.2923, longitude: 36.8221),
          animalName: 'Bison',
        ),
      ];

      repository.seed(alerts);

      final activeAlerts = await repository.watchActiveAlerts().first;
      expect(activeAlerts.length, equals(2)); // Only active alerts
      expect(
        activeAlerts.first.animalName,
        equals('Bison'),
      ); // Most recent first
      expect(activeAlerts.last.animalName, equals('Jumbo'));
    });
  });

  group('InMemoryAlertRecipientRepository', () {
    late InMemoryAlertRecipientRepository repository;

    setUp(() {
      repository = InMemoryAlertRecipientRepository();
    });

    tearDown(() {
      repository.dispose();
    });

    test('fans out recipients for alert', () async {
      final recipients = [
        const AlertRecipient(
          officerId: 'officer-01',
          officerName: 'Ranger John',
          role: 'ranger',
          deliveryStatus: 'pending',
          notifiedChannels: ['inApp'],
        ),
        const AlertRecipient(
          officerId: 'officer-02',
          officerName: 'CLO Jane',
          role: 'clo',
          deliveryStatus: 'pending',
          notifiedChannels: ['inApp', 'fcm'],
        ),
      ];

      await repository.fanOut('alert-01', recipients);

      final alertRecipients = await repository.watchForAlert('alert-01').first;
      expect(alertRecipients.length, equals(2));
      expect(
        alertRecipients.map((r) => r.officerName),
        containsAll(['Ranger John', 'CLO Jane']),
      );
    });

    test('marks recipient as read', () async {
      final recipient = const AlertRecipient(
        officerId: 'officer-01',
        officerName: 'Ranger John',
        role: 'ranger',
        deliveryStatus: 'pending',
      );

      await repository.fanOut('alert-01', [recipient]);
      await repository.markRead('alert-01', 'officer-01');

      final alertRecipients = await repository.watchForAlert('alert-01').first;
      final updatedRecipient = alertRecipients.first;
      expect(updatedRecipient.deliveryStatus, equals('read'));
      expect(updatedRecipient.readAt, isNotNull);
    });
  });

  group('InMemoryOfficerRepository', () {
    late InMemoryOfficerRepository repository;

    setUp(() {
      repository = InMemoryOfficerRepository();
    });

    test('returns officers by role', () async {
      final officers = [
        const Officer(
          officerId: 'officer-01',
          name: 'Ranger John',
          role: 'ranger',
          contactNo: '+254701234567',
        ),
        const Officer(officerId: 'officer-02', name: 'CLO Jane', role: 'clo'),
        const Officer(
          officerId: 'officer-03',
          name: 'Ranger Bob',
          role: 'ranger',
          contactNo: '+254701234568',
        ),
      ];

      repository.seed(officers);

      final rangers = await repository.getByRole('ranger');
      expect(rangers.length, equals(2));
      expect(
        rangers.map((o) => o.name),
        containsAll(['Ranger John', 'Ranger Bob']),
      );

      final clos = await repository.getByRole('clo');
      expect(clos.length, equals(1));
      expect(clos.first.name, equals('CLO Jane'));
    });

    test('manages FCM tokens correctly', () async {
      final officer = const Officer(
        officerId: 'officer-01',
        name: 'Ranger John',
        role: 'ranger',
        fcmTokens: ['token1'],
      );

      repository.seed([officer]);

      // Add new token
      await repository.addFcmToken('officer-01', 'token2');
      var updated = (await repository.getAll()).first;
      expect(updated.fcmTokens, containsAll(['token1', 'token2']));

      // Don't add duplicate token
      await repository.addFcmToken('officer-01', 'token1');
      updated = (await repository.getAll()).first;
      expect(updated.fcmTokens.length, equals(2)); // Still 2 tokens

      // Remove token
      await repository.removeFcmToken('officer-01', 'token1');
      updated = (await repository.getAll()).first;
      expect(updated.fcmTokens, equals(['token2']));
    });

    test('updates officer location', () async {
      final officer = const Officer(
        officerId: 'officer-01',
        name: 'Ranger John',
        role: 'ranger',
      );

      repository.seed([officer]);

      final newLocation = const GeoPoint(-1.2921, 36.8219);
      final timestamp = Timestamp.now();

      await repository.updateLocation('officer-01', newLocation, timestamp);

      final updated = (await repository.getAll()).first;
      expect(updated.location, equals(newLocation));
      expect(updated.locationUpdatedAt, equals(timestamp));
    });
  });

  group('InMemoryDutyRosterRepository', () {
    late InMemoryDutyRosterRepository repository;

    setUp(() {
      repository = InMemoryDutyRosterRepository();
    });

    test('returns duty roster by date', () async {
      final roster = DutyRoster(
        date: '2024-01-15',
        onDutyRangerIds: ['officer-01', 'officer-03'],
        lastUpdated: Timestamp.now(),
      );

      repository.seed([roster]);

      final result = await repository.getByDate('2024-01-15');
      expect(result, isNotNull);
      expect(
        result!.onDutyRangerIds,
        containsAll(['officer-01', 'officer-03']),
      );
      expect(result.isOnDuty('officer-01'), isTrue);
      expect(result.isOnDuty('officer-02'), isFalse);
    });

    test('returns null for non-existent date', () async {
      final result = await repository.getByDate('2024-12-25');
      expect(result, isNull);
    });
  });

  group('InMemoryUserPreferencesRepository', () {
    late InMemoryUserPreferencesRepository repository;

    setUp(() {
      repository = InMemoryUserPreferencesRepository();
    });

    tearDown(() {
      repository.dispose();
    });

    test('returns theme mode for user', () async {
      final preferences = UserPreferences(
        userId: 'user-01',
        themeMode: 'dark',
        lastUpdated: Timestamp.now(),
      );

      repository.seed([preferences]);

      final result = await repository.getThemeMode('user-01');
      expect(result, equals('dark'));
    });

    test('sets and watches theme mode changes', () async {
      final stream = repository.watchThemeMode('user-01');

      await repository.setThemeMode('user-01', 'light');

      final themeMode = await stream.first;
      expect(themeMode, equals('light'));
    });

    test('returns null for non-existent user', () async {
      final result = await repository.getThemeMode('non-existent');
      expect(result, isNull);
    });
  });
}
