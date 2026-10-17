import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wildora/src/data/models/alert.dart';
import 'package:wildora/src/data/models/alert_recipient.dart';
import 'package:wildora/src/data/models/animal.dart';
import 'package:wildora/src/data/models/high_risk_zone.dart';
import 'package:wildora/src/features/high_risk_movement/application/animal_monitoring_controller.dart';
import 'package:wildora/src/features/high_risk_movement/application/high_risk_zone_detection_service.dart';
import 'package:wildora/src/features/high_risk_movement/domain/geo.dart';
import 'package:wildora/src/features/high_risk_movement/domain/monitoring_state.dart';
import 'package:wildora/src/features/high_risk_movement/domain/zone_check_result.dart';

import '../fakes/in_memory_repositories.dart';

/// Local stubbable detection service (minimal mock shape copied from the
/// existing controller test) so each scenario is deterministic without
/// depending on real proximity/geometry calculations.
class MockHighRiskZoneDetectionService extends HighRiskZoneDetectionService {
  ZoneCheckResult? nextZoneCheckResult;
  List<String>? nextNearbyRecipients;

  MockHighRiskZoneDetectionService({
    required super.officerRepository,
    required super.dutyRosterRepository,
    required super.zoneRepository,
  });

  @override
  Future<ZoneCheckResult> checkZones(GeoPoint2D location) async {
    return nextZoneCheckResult ?? ZoneCheckResult.notInZone();
  }

  @override
  Future<List<String>> resolveNearbyRecipients(
    GeoPoint zoneCenter,
    DateTime now,
  ) async {
    return nextNearbyRecipients ?? [];
  }
}

void main() {
  group('AnimalMonitoringController additional', () {
    late AnimalMonitoringController controller;
    late InMemoryAnimalRepository animalRepo;
    late InMemoryAlertRepository alertRepo;
    late InMemoryAlertRecipientRepository alertRecipientRepo;
    late InMemoryHighRiskZoneRepository zoneRepo;
    late MockHighRiskZoneDetectionService detectionService;

    // Deterministic injected time (no real clock / delays).
    final detectedAt = DateTime(2026, 10, 16, 9, 30);

    setUp(() {
      animalRepo = InMemoryAnimalRepository();
      alertRepo = InMemoryAlertRepository();
      alertRecipientRepo = InMemoryAlertRecipientRepository();
      zoneRepo = InMemoryHighRiskZoneRepository();

      detectionService = MockHighRiskZoneDetectionService(
        officerRepository: InMemoryOfficerRepository(),
        dutyRosterRepository: InMemoryDutyRosterRepository(),
        zoneRepository: zoneRepo,
      );

      controller = AnimalMonitoringController(
        animalRepository: animalRepo,
        alertRepository: alertRepo,
        alertRecipientRepository: alertRecipientRepo,
        detectionService: detectionService,
        zoneRepository: zoneRepo,
      );
    });

    tearDown(() {
      controller.dispose();
    });

    Animal collaredAnimal() => const Animal(
      animalId: 'elephant-23',
      name: 'Elephant-23',
      species: 'Elephant',
      collarId: 'collar-001',
      currentLocation: null,
    );

    // (1) ORDERING: location persisted BEFORE the risk-handling throw.
    //
    // NOTE on expected message: when the matched zone is NOT present in
    // zoneRepository.getAll(), the production code's `zones.firstWhere(...)`
    // (in onLocationReceivedCoordinates, before _handleHighRiskDetected) throws
    // a StateError which is caught by the OUTER try/catch, producing a
    // 'Location processing failed' message rather than 'Alert creation failed'.
    // We therefore assert the ACTUAL message the production code emits. The
    // ordering guarantee (location persisted before the throw) is still fully
    // verified. Modifying production code to change this message is out of scope.
    test(
      '(1) persists currentLocation before risk handling throws (non-seeded zone)',
      () async {
        await animalRepo.create(collaredAnimal());

        // Matched zone id points to a zone that is NOT seeded in zoneRepo.
        detectionService.nextZoneCheckResult = ZoneCheckResult.inZone(
          zoneId: 'zone-does-not-exist',
          distance: 100.0,
        );

        await controller.onLocationReceivedCoordinates(
          'elephant-23',
          -1.2921,
          36.8219,
          detectedAt,
        );

        // (i) Location WAS persisted before the throw.
        final persisted = await animalRepo.getById('elephant-23');
        expect(persisted?.currentLocation, isNotNull);
        expect(persisted?.currentLocation?.latitude, equals(-1.2921));
        expect(persisted?.currentLocation?.longitude, equals(36.8219));

        // (ii) Controller ended in error state with a failure message.
        expect(controller.state, equals(MonitoringState.error));
        expect(controller.errorMessage, isNotNull);
        // Actual production message for a missing zone (see NOTE above).
        expect(controller.errorMessage, contains('Location processing failed'));
        expect(controller.lastResult, isNull);

        // No alert should have been created.
        final alerts = await alertRepo.getAll();
        expect(alerts, isEmpty);
      },
    );

    // (1b) 'Alert creation failed' path: zone IS seeded so firstWhere succeeds,
    // but alert creation fails inside _handleHighRiskDetected. This proves the
    // 'Alert creation failed' branch AND that location was persisted first.
    test(
      '(1b) persists location then surfaces "Alert creation failed" when create throws',
      () async {
        await animalRepo.create(collaredAnimal());

        final zone = HighRiskZone(
          zoneId: 'zone-seeded',
          name: 'Seeded Zone',
          riskLevel: 'High',
          center: GeoPoint(-1.2921, 36.8219),
          radiusMeters: 500.0,
        );
        await zoneRepo.create(zone);

        detectionService.nextZoneCheckResult = ZoneCheckResult.inZone(
          zoneId: zone.zoneId,
          distance: 100.0,
        );
        detectionService.nextNearbyRecipients = ['officer-1'];

        // Make alert creation throw inside _handleHighRiskDetected.
        alertRepo.forceError = true;

        await controller.onLocationReceivedCoordinates(
          'elephant-23',
          -1.2921,
          36.8219,
          detectedAt,
        );

        // Location persisted before the alert-creation throw.
        final persisted = await animalRepo.getById('elephant-23');
        expect(persisted?.currentLocation?.latitude, equals(-1.2921));

        expect(controller.state, equals(MonitoringState.error));
        expect(controller.errorMessage, contains('Alert creation failed'));
      },
    );

    group('(2) NO-PERSIST on skip', () {
      test('animal not found => no currentLocation write + idle', () async {
        // No animal seeded.
        await controller.onLocationReceived(
          'ghost-animal',
          AnimalLocation(
            latitude: 1.0,
            longitude: 2.0,
            timestamp: Timestamp.fromDate(detectedAt),
          ),
        );

        expect(controller.state, equals(MonitoringState.idle));
        expect(
          controller.lastResult,
          equals('Animal ghost-animal not found - skipped'),
        );
        expect(controller.errorMessage, isNull);

        // Nothing was stored for this animal.
        final stored = await animalRepo.getById('ghost-animal');
        expect(stored, isNull);
      });

      test('animal present but collarId null => no location write + idle', () async {
        const noCollar = Animal(
          animalId: 'buffalo-11',
          name: 'Buffalo 11',
          species: 'Buffalo',
          collarId: null,
          currentLocation: null,
        );
        await animalRepo.create(noCollar);

        await controller.onLocationReceived(
          'buffalo-11',
          AnimalLocation(
            latitude: 1.0,
            longitude: 2.0,
            timestamp: Timestamp.fromDate(detectedAt),
          ),
        );

        expect(controller.state, equals(MonitoringState.idle));
        expect(
          controller.lastResult,
          equals('Animal Buffalo 11 has no collar - skipped'),
        );
        expect(controller.errorMessage, isNull);

        // The stored animal remains unchanged (no currentLocation written).
        final stored = await animalRepo.getById('buffalo-11');
        expect(stored?.currentLocation, isNull);
      });
    });

    // (3) DELEGATION: onLocationReceived == onLocationReceivedCoordinates.
    test(
      '(3) onLocationReceived delegates to coordinates variant (equal effect)',
      () async {
        // Fresh controller/fakes "A" for the AnimalLocation path.
        final animalRepoA = InMemoryAnimalRepository();
        final alertRepoA = InMemoryAlertRepository();
        final recipientRepoA = InMemoryAlertRecipientRepository();
        final zoneRepoA = InMemoryHighRiskZoneRepository();
        final detectionA = MockHighRiskZoneDetectionService(
          officerRepository: InMemoryOfficerRepository(),
          dutyRosterRepository: InMemoryDutyRosterRepository(),
          zoneRepository: zoneRepoA,
        )..nextZoneCheckResult = ZoneCheckResult.notInZone();
        final controllerA = AnimalMonitoringController(
          animalRepository: animalRepoA,
          alertRepository: alertRepoA,
          alertRecipientRepository: recipientRepoA,
          detectionService: detectionA,
          zoneRepository: zoneRepoA,
        );
        await animalRepoA.create(collaredAnimal());

        // Fresh controller/fakes "B" for the coordinates path.
        final animalRepoB = InMemoryAnimalRepository();
        final alertRepoB = InMemoryAlertRepository();
        final recipientRepoB = InMemoryAlertRecipientRepository();
        final zoneRepoB = InMemoryHighRiskZoneRepository();
        final detectionB = MockHighRiskZoneDetectionService(
          officerRepository: InMemoryOfficerRepository(),
          dutyRosterRepository: InMemoryDutyRosterRepository(),
          zoneRepository: zoneRepoB,
        )..nextZoneCheckResult = ZoneCheckResult.notInZone();
        final controllerB = AnimalMonitoringController(
          animalRepository: animalRepoB,
          alertRepository: alertRepoB,
          alertRecipientRepository: recipientRepoB,
          detectionService: detectionB,
          zoneRepository: zoneRepoB,
        );
        await animalRepoB.create(collaredAnimal());

        const lat = -1.2921;
        const lng = 36.8219;

        await controllerA.onLocationReceived(
          'elephant-23',
          AnimalLocation(
            latitude: lat,
            longitude: lng,
            timestamp: Timestamp.fromDate(detectedAt),
          ),
        );
        await controllerB.onLocationReceivedCoordinates(
          'elephant-23',
          lat,
          lng,
          detectedAt,
        );

        // Same outcome state + message.
        expect(controllerA.state, equals(controllerB.state));
        expect(controllerA.state, equals(MonitoringState.noAlert));
        expect(controllerA.lastResult, equals(controllerB.lastResult));

        // Same persisted coordinates.
        final a = await animalRepoA.getById('elephant-23');
        final b = await animalRepoB.getById('elephant-23');
        expect(a?.currentLocation?.latitude, equals(b?.currentLocation?.latitude));
        expect(a?.currentLocation?.longitude, equals(b?.currentLocation?.longitude));
        expect(a?.currentLocation?.latitude, equals(lat));
        expect(a?.currentLocation?.longitude, equals(lng));

        controllerA.dispose();
        controllerB.dispose();
      },
    );

    group('(4) snapshot risk + alert fields', () {
      test('High zone => alert.riskLevel == "High" with snapshot fields', () async {
        await animalRepo.create(collaredAnimal());

        final zone = HighRiskZone(
          zoneId: 'zone-high',
          name: 'High Zone',
          riskLevel: 'High',
          center: GeoPoint(-1.2921, 36.8219),
          radiusMeters: 500.0,
        );
        await zoneRepo.create(zone);

        detectionService.nextZoneCheckResult = ZoneCheckResult.inZone(
          zoneId: zone.zoneId,
          distance: 120.0,
        );
        detectionService.nextNearbyRecipients = ['ranger-1'];

        await controller.onLocationReceivedCoordinates(
          'elephant-23',
          -1.2921,
          36.8219,
          detectedAt,
        );

        final alerts = await alertRepo.getAll();
        expect(alerts, hasLength(1));
        final alert = alerts.first;
        expect(alert.riskLevel, equals('High'));
        expect(alert.status, equals('active'));
        expect(alert.responseStatus, equals(AlertResponseStatus.unclaimed));
        // timestamp snapshot == injected detectedAt.
        expect(alert.timestamp.toDate(), equals(detectedAt));
      });

      test('Low zone => alert.riskLevel == "Low"', () async {
        await animalRepo.create(collaredAnimal());

        final zone = HighRiskZone(
          zoneId: 'zone-low',
          name: 'Low Zone',
          riskLevel: 'Low',
          center: GeoPoint(-1.2921, 36.8219),
          radiusMeters: 500.0,
        );
        await zoneRepo.create(zone);

        detectionService.nextZoneCheckResult = ZoneCheckResult.inZone(
          zoneId: zone.zoneId,
          distance: 120.0,
        );
        detectionService.nextNearbyRecipients = ['ranger-1'];

        await controller.onLocationReceivedCoordinates(
          'elephant-23',
          -1.2921,
          36.8219,
          detectedAt,
        );

        final alerts = await alertRepo.getAll();
        expect(alerts, hasLength(1));
        expect(alerts.first.riskLevel, equals('Low'));
        expect(alerts.first.timestamp.toDate(), equals(detectedAt));
      });
    });

    // (5) FANOUT ERROR: in-zone + recipients resolved, but fanOut throws.
    test(
      '(5) fan-out error => error state after alert was created',
      () async {
        await animalRepo.create(collaredAnimal());

        final zone = HighRiskZone(
          zoneId: 'zone-fanout',
          name: 'Fanout Zone',
          riskLevel: 'High',
          center: GeoPoint(-1.2921, 36.8219),
          radiusMeters: 500.0,
        );
        await zoneRepo.create(zone);

        detectionService.nextZoneCheckResult = ZoneCheckResult.inZone(
          zoneId: zone.zoneId,
          distance: 100.0,
        );
        detectionService.nextNearbyRecipients = ['ranger-1'];

        // Fan-out fails AFTER the alert has been created.
        alertRecipientRepo.forceError = true;

        await controller.onLocationReceivedCoordinates(
          'elephant-23',
          -1.2921,
          36.8219,
          detectedAt,
        );

        expect(controller.state, equals(MonitoringState.error));
        expect(controller.errorMessage, contains('Alert creation failed'));

        // Alert was created before fan-out threw.
        final alerts = await alertRepo.getAll();
        expect(alerts, hasLength(1));
        expect(alerts.first.zoneId, equals('zone-fanout'));
      },
    );

    // (6) SINGLE-RECIPIENT grammar + fanned-out recipient shape.
    test(
      '(6) single recipient => "Notified 1 nearby officer(s)" + recipient shape',
      () async {
        await animalRepo.create(collaredAnimal());

        final zone = HighRiskZone(
          zoneId: 'zone-single',
          name: 'Single Officer Zone',
          riskLevel: 'High',
          center: GeoPoint(-1.2921, 36.8219),
          radiusMeters: 500.0,
        );
        await zoneRepo.create(zone);

        detectionService.nextZoneCheckResult = ZoneCheckResult.inZone(
          zoneId: zone.zoneId,
          distance: 100.0,
        );
        detectionService.nextNearbyRecipients = ['ranger-amara'];

        await controller.onLocationReceivedCoordinates(
          'elephant-23',
          -1.2921,
          36.8219,
          detectedAt,
        );

        expect(controller.state, equals(MonitoringState.alertRaised));
        expect(
          controller.lastResult,
          contains('Notified 1 nearby officer(s)'),
        );

        // The fanned-out recipient shape is recorded by the fake.
        expect(alertRecipientRepo.lastFanOutOfficerIds, equals(['ranger-amara']));
        expect(
          alertRecipientRepo.lastFanOutChannels,
          equals(['inApp', 'fcm']),
        );
        // Inspect the actual stored recipient to assert all fields.
        final alertId = alertRecipientRepo.lastFanOutAlertId;
        expect(alertId, isNotNull);
        final recipients = <AlertRecipient>[];
        final sub = alertRecipientRepo
            .watchForAlert(alertId!)
            .listen(recipients.addAll);
        await Future<void>.value();
        await sub.cancel();

        expect(recipients, hasLength(1));
        final r = recipients.first;
        expect(r.officerId, equals('ranger-amara'));
        expect(r.officerName, equals('Officer ranger-amara'));
        expect(r.role, equals('unknown'));
        expect(r.deliveryStatus, equals('pending'));
        expect(r.notifiedChannels, equals(['inApp', 'fcm']));
      },
    );

    // (7) LASTALERT MISMATCH: local update only applies when ids match.
    test(
      '(7) claim/resolve of a different alert id leaves lastAlert unchanged',
      () async {
        await animalRepo.create(collaredAnimal());

        final zone = HighRiskZone(
          zoneId: 'zone-a',
          name: 'Zone A',
          riskLevel: 'High',
          center: GeoPoint(-1.2921, 36.8219),
          radiusMeters: 500.0,
        );
        await zoneRepo.create(zone);

        detectionService.nextZoneCheckResult = ZoneCheckResult.inZone(
          zoneId: zone.zoneId,
          distance: 100.0,
        );
        detectionService.nextNearbyRecipients = ['ranger-1'];

        // Raise an alert (alertA) via the real flow; it becomes lastAlert.
        await controller.onLocationReceivedCoordinates(
          'elephant-23',
          -1.2921,
          36.8219,
          detectedAt,
        );

        final alertA = controller.lastAlert;
        expect(alertA, isNotNull);
        expect(alertA!.responseStatus, equals(AlertResponseStatus.unclaimed));
        final alertAId = alertA.alertId;

        // Create a SEPARATE alert (alertB) directly in the repo so claim/resolve
        // succeed at the repository level but target a different id.
        final alertBSeed = Alert(
          alertId: '',
          type: 'high_risk_movement',
          timestamp: Timestamp.fromDate(detectedAt),
          status: 'active',
          responseStatus: AlertResponseStatus.unclaimed,
          animalId: 'elephant-23',
          animalName: 'Elephant-23',
          zoneId: 'zone-a',
          location: const AlertLocation(latitude: 0.0, longitude: 0.0),
          locationLabel: 'Zone A',
        );
        final alertBId = await alertRepo.create(alertBSeed);
        expect(alertBId, isNot(equals(alertAId)));

        // Claim + resolve alertB (different from lastAlert/alertA).
        final claimed = await controller.claimResponse(
          alertBId,
          'ranger-2',
          'Ranger Two',
        );
        expect(claimed, isTrue);
        await controller.resolveAlert(alertBId);

        // lastAlert is still alertA and UNCHANGED (ids never matched).
        expect(controller.lastAlert?.alertId, equals(alertAId));
        expect(
          controller.lastAlert?.responseStatus,
          equals(AlertResponseStatus.unclaimed),
        );
        expect(controller.lastAlert?.respondingOfficerId, isNull);
        expect(controller.lastAlert?.resolvedAt, isNull);
      },
    );

    // (8) NOTIFY: listener fires for claim (true/false), resolve, acknowledge.
    group('(8) notifyListeners', () {
      test('fires on claimResponse success (true)', () async {
        final alert = Alert(
          alertId: '',
          type: 'high_risk_movement',
          timestamp: Timestamp.fromDate(detectedAt),
          status: 'active',
          responseStatus: AlertResponseStatus.unclaimed,
          animalId: 'elephant-23',
          animalName: 'Elephant-23',
          zoneId: 'zone-test',
          location: const AlertLocation(latitude: 0.0, longitude: 0.0),
          locationLabel: 'Test Zone',
        );
        final alertId = await alertRepo.create(alert);

        var count = 0;
        controller.addListener(() => count++);

        final ok = await controller.claimResponse(alertId, 'r1', 'Ranger One');
        expect(ok, isTrue);
        expect(count, greaterThan(0));
      });

      test('fires on claimResponse failure (false)', () async {
        final alert = Alert(
          alertId: '',
          type: 'high_risk_movement',
          timestamp: Timestamp.fromDate(detectedAt),
          status: 'active',
          responseStatus: AlertResponseStatus.unclaimed,
          animalId: 'elephant-23',
          animalName: 'Elephant-23',
          zoneId: 'zone-test',
          location: const AlertLocation(latitude: 0.0, longitude: 0.0),
          locationLabel: 'Test Zone',
        );
        final alertId = await alertRepo.create(alert);
        alertRepo.nextClaimResult = false; // force already-claimed path

        var count = 0;
        controller.addListener(() => count++);

        final ok = await controller.claimResponse(alertId, 'r1', 'Ranger One');
        expect(ok, isFalse);
        expect(count, greaterThan(0));
      });

      test('fires on resolveAlert', () async {
        final alert = Alert(
          alertId: '',
          type: 'high_risk_movement',
          timestamp: Timestamp.fromDate(detectedAt),
          status: 'active',
          responseStatus: AlertResponseStatus.responding,
          respondingOfficerId: 'r1',
          respondingOfficerName: 'Ranger One',
          respondingAt: Timestamp.fromDate(detectedAt),
          animalId: 'elephant-23',
          animalName: 'Elephant-23',
          zoneId: 'zone-test',
          location: const AlertLocation(latitude: 0.0, longitude: 0.0),
          locationLabel: 'Test Zone',
        );
        final alertId = await alertRepo.create(alert);

        var count = 0;
        controller.addListener(() => count++);

        await controller.resolveAlert(alertId);
        expect(count, greaterThan(0));
      });

      test('fires on acknowledgeAlert but does NOT change state', () async {
        final before = controller.state;

        var count = 0;
        controller.addListener(() => count++);

        await controller.acknowledgeAlert('alert-x', 'officer-x');

        expect(count, greaterThan(0));
        expect(controller.lastResult, equals('Alert acknowledged'));
        // acknowledgeAlert never calls _setState, so state is unchanged.
        expect(controller.state, equals(before));
      });
    });
  });
}
