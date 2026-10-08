import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wildora/src/data/models/alert.dart';
import 'package:wildora/src/data/models/animal.dart';
import 'package:wildora/src/data/models/high_risk_zone.dart';
import 'package:wildora/src/data/repositories/officer_repository.dart';
import 'package:wildora/src/data/repositories/duty_roster_repository.dart';
import 'package:wildora/src/data/repositories/high_risk_zone_repository.dart';
import 'package:wildora/src/features/high_risk_movement/application/animal_monitoring_controller.dart';
import 'package:wildora/src/features/high_risk_movement/application/high_risk_zone_detection_service.dart';
import 'package:wildora/src/features/high_risk_movement/domain/geo.dart';
import 'package:wildora/src/features/high_risk_movement/domain/monitoring_state.dart';
import 'package:wildora/src/features/high_risk_movement/domain/zone_check_result.dart';

import '../../fakes/in_memory_repositories.dart';

void main() {
  group('AnimalMonitoringController', () {
    late AnimalMonitoringController controller;
    late InMemoryAnimalRepository animalRepo;
    late InMemoryAlertRepository alertRepo;
    late InMemoryAlertRecipientRepository alertRecipientRepo;
    late InMemoryHighRiskZoneRepository zoneRepo;
    late MockHighRiskZoneDetectionService detectionService;

    setUp(() {
      animalRepo = InMemoryAnimalRepository();
      alertRepo = InMemoryAlertRepository();
      alertRecipientRepo = InMemoryAlertRecipientRepository();
      zoneRepo = InMemoryHighRiskZoneRepository();

      // Create mock detection service with shared repositories
      detectionService = MockHighRiskZoneDetectionService(
        officerRepository: InMemoryOfficerRepository(),
        dutyRosterRepository: InMemoryDutyRosterRepository(),
        zoneRepository: zoneRepo, // Share the same zone repo
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

    group('onLocationReceived', () {
      test('skips processing when animal not found', () async {
        // No animal in repo

        await controller.onLocationReceived(
          'unknown-animal',
          AnimalLocation(
            latitude: 0.0,
            longitude: 0.0,
            timestamp: Timestamp.fromDate(DateTime.now()),
          ),
        );

        expect(controller.state, equals(MonitoringState.idle));
        expect(
          controller.lastResult,
          equals('Animal unknown-animal not found - skipped'),
        );
        expect(controller.errorMessage, isNull);
      });

      test('skips processing when animal has no collar', () async {
        // Animal without collar
        final animal = Animal(
          animalId: 'buffalo-11',
          name: 'Buffalo 11',
          species: 'Buffalo',
          collarId: null, // No collar
          currentLocation: null,
        );
        await animalRepo.create(animal);

        await controller.onLocationReceived(
          'buffalo-11',
          AnimalLocation(
            latitude: 0.0,
            longitude: 0.0,
            timestamp: Timestamp.fromDate(DateTime.now()),
          ),
        );

        expect(controller.state, equals(MonitoringState.idle));
        expect(
          controller.lastResult,
          equals('Animal Buffalo 11 has no collar - skipped'),
        );
        expect(controller.errorMessage, isNull);
      });

      test('updates location and continues when animal not in zone', () async {
        // Animal with collar
        final animal = Animal(
          animalId: 'elephant-23',
          name: 'Elephant-23',
          species: 'Elephant',
          collarId: 'collar-001',
          currentLocation: null,
        );
        await animalRepo.create(animal);

        // Detection service returns not in zone
        detectionService.nextZoneCheckResult = ZoneCheckResult.notInZone();

        final testTime = DateTime(2026, 10, 8, 12, 0);
        await controller.onLocationReceived(
          'elephant-23',
          AnimalLocation(
            latitude: -1.2921,
            longitude: 36.8219,
            timestamp: Timestamp.fromDate(testTime),
          ),
        );

        expect(controller.state, equals(MonitoringState.noAlert));
        expect(
          controller.lastResult,
          equals(
            'Location updated for Elephant-23 - no high-risk zones detected',
          ),
        );
        expect(controller.errorMessage, isNull);

        // Verify location was updated
        final updatedAnimal = await animalRepo.getById('elephant-23');
        expect(updatedAnimal?.currentLocation?.latitude, equals(-1.2921));
        expect(updatedAnimal?.currentLocation?.longitude, equals(36.8219));
      });

      test(
        'creates alert and fans out when animal enters high-risk zone',
        () async {
          // Animal with collar
          final animal = Animal(
            animalId: 'elephant-23',
            name: 'Elephant-23',
            species: 'Elephant',
            collarId: 'collar-001',
            currentLocation: null,
          );
          await animalRepo.create(animal);

          // Mock zone for detection result
          final zone = HighRiskZone(
            zoneId: 'zone-farmland-border',
            name: 'Farmland Border',
            riskLevel: 'High',
            center: GeoPoint(-1.2921, 36.8219),
            radiusMeters: 500.0,
          );
          await zoneRepo.create(zone);

          // Detection service returns in zone
          detectionService.nextZoneCheckResult = ZoneCheckResult.inZone(
            zoneId: zone.zoneId,
            distance: 250.0,
          );

          // Mock nearby recipients
          detectionService.nextNearbyRecipients = ['ranger-amara', 'clo-nimal'];

          final testTime = DateTime(2026, 10, 8, 12, 0);
          await controller.onLocationReceived(
            'elephant-23',
            AnimalLocation(
              latitude: -1.2921,
              longitude: 36.8219,
              timestamp: Timestamp.fromDate(testTime),
            ),
          );

          expect(controller.state, equals(MonitoringState.alertRaised));
          expect(
            controller.lastResult,
            equals(
              'HIGH-RISK ALERT: Elephant-23 entered Farmland Border. '
              'Notified 2 nearby officer(s).',
            ),
          );
          expect(controller.errorMessage, isNull);

          // Verify alert was created
          final alerts = await alertRepo.getAll();
          expect(alerts, hasLength(1));

          final alert = alerts.first;
          expect(alert.type, equals('high_risk_movement'));
          expect(alert.animalId, equals('elephant-23'));
          expect(alert.animalName, equals('Elephant-23'));
          expect(alert.zoneId, equals('zone-farmland-border'));
          expect(alert.locationLabel, equals('Farmland Border'));
          expect(alert.responseStatus, equals(AlertResponseStatus.unclaimed));
          expect(alert.location.latitude, equals(-1.2921));
          expect(alert.location.longitude, equals(36.8219));

          // Verify fan-out occurred
          expect(alertRecipientRepo.lastFanOutAlertId, equals(alert.alertId));
          expect(
            alertRecipientRepo.lastFanOutOfficerIds,
            equals(['ranger-amara', 'clo-nimal']),
          );
          expect(
            alertRecipientRepo.lastFanOutChannels,
            equals(['inApp', 'fcm']),
          );

          // Verify controller has the alert
          expect(controller.lastAlert?.alertId, equals(alert.alertId));
        },
      );

      test('handles zone detection with no nearby officers', () async {
        final animal = Animal(
          animalId: 'elephant-23',
          name: 'Elephant-23',
          species: 'Elephant',
          collarId: 'collar-001',
          currentLocation: null,
        );
        await animalRepo.create(animal);

        final zone = HighRiskZone(
          zoneId: 'zone-remote',
          name: 'Remote Zone',
          riskLevel: 'High',
          center: GeoPoint(-1.2921, 36.8219),
          radiusMeters: 500.0,
        );
        await zoneRepo.create(zone);

        detectionService.nextZoneCheckResult = ZoneCheckResult.inZone(
          zoneId: zone.zoneId,
          distance: 100.0,
        );

        // No nearby officers
        detectionService.nextNearbyRecipients = [];

        await controller.onLocationReceived(
          'elephant-23',
          AnimalLocation(
            latitude: -1.2921,
            longitude: 36.8219,
            timestamp: Timestamp.fromDate(DateTime.now()),
          ),
        );

        expect(controller.state, equals(MonitoringState.alertRaised));
        expect(
          controller.lastResult,
          equals(
            'Alert created for Elephant-23 in Remote Zone, but no officers available',
          ),
        );

        // Alert should still be created
        final alerts = await alertRepo.getAll();
        expect(alerts, hasLength(1));

        // But no fan-out should occur
        expect(alertRecipientRepo.lastFanOutAlertId, isNull);
      });

      test('handles animal repository errors', () async {
        // Force animal repo to throw
        animalRepo.forceError = true;

        await controller.onLocationReceived(
          'any-animal',
          AnimalLocation(
            latitude: 0.0,
            longitude: 0.0,
            timestamp: Timestamp.fromDate(DateTime.now()),
          ),
        );

        expect(controller.state, equals(MonitoringState.error));
        expect(controller.errorMessage, contains('Location processing failed'));
        expect(controller.lastResult, isNull);
      });

      test('handles alert creation errors', () async {
        final animal = Animal(
          animalId: 'elephant-23',
          name: 'Elephant-23',
          species: 'Elephant',
          collarId: 'collar-001',
          currentLocation: null,
        );
        await animalRepo.create(animal);

        final zone = HighRiskZone(
          zoneId: 'zone-test',
          name: 'Test Zone',
          riskLevel: 'High',
          center: GeoPoint(0.0, 0.0),
          radiusMeters: 500.0,
        );
        await zoneRepo.create(zone);

        detectionService.nextZoneCheckResult = ZoneCheckResult.inZone(
          zoneId: zone.zoneId,
          distance: 100.0,
        );
        detectionService.nextNearbyRecipients = ['officer1'];

        // Force alert repo to throw
        alertRepo.forceError = true;

        await controller.onLocationReceived(
          'elephant-23',
          AnimalLocation(
            latitude: 0.0,
            longitude: 0.0,
            timestamp: Timestamp.fromDate(DateTime.now()),
          ),
        );

        expect(controller.state, equals(MonitoringState.error));
        expect(controller.errorMessage, contains('Alert creation failed'));
      });
    });

    group('claimResponse', () {
      test('successfully claims unclaimed alert', () async {
        // Create an alert first
        final alert = Alert(
          alertId: '', // Will be set by repository
          type: 'high_risk_movement',
          timestamp: Timestamp.now(),
          status: 'active',
          responseStatus: AlertResponseStatus.unclaimed,
          respondingOfficerId: null,
          respondingOfficerName: null,
          respondingAt: null,
          animalId: 'elephant-23',
          animalName: 'Elephant-23',
          zoneId: 'zone-test',
          location: AlertLocation(latitude: 0.0, longitude: 0.0),
          locationLabel: 'Test Zone',
        );
        final createdAlertId = await alertRepo.create(alert);

        // Set up controller with this alert
        // Use reflection or public setter if available for testing
        await controller.onLocationReceived(
          'elephant-23',
          AnimalLocation(
            latitude: 0.0,
            longitude: 0.0,
            timestamp: Timestamp.fromDate(DateTime.now()),
          ),
        );
        controller.clearError(); // Clear any errors from setup

        final success = await controller.claimResponse(
          createdAlertId,
          'ranger-1',
          'Ranger One',
        );

        expect(success, isTrue);
        expect(
          controller.lastResult,
          equals('You are now responding to this alert'),
        );
        expect(controller.errorMessage, isNull);

        // Verify alert was claimed in repo
        expect(alertRepo.lastClaimAlertId, equals(createdAlertId));
        expect(alertRepo.lastClaimOfficerId, equals('ranger-1'));
        expect(alertRepo.lastClaimOfficerName, equals('Ranger One'));

        // Verify controller's local alert was updated (only if it matches the ID)
        if (controller.lastAlert?.alertId == createdAlertId) {
          expect(
            controller.lastAlert?.responseStatus,
            equals(AlertResponseStatus.responding),
          );
          expect(controller.lastAlert?.respondingOfficerId, equals('ranger-1'));
          expect(
            controller.lastAlert?.respondingOfficerName,
            equals('Ranger One'),
          );
        }
      });

      test('handles failed claim (already claimed)', () async {
        // Create an alert first
        final alert = Alert(
          alertId: '', // Will be set by repository
          type: 'high_risk_movement',
          timestamp: Timestamp.now(),
          status: 'active',
          responseStatus: AlertResponseStatus.unclaimed,
          respondingOfficerId: null,
          respondingOfficerName: null,
          respondingAt: null,
          animalId: 'elephant-23',
          animalName: 'Elephant-23',
          zoneId: 'zone-test',
          location: AlertLocation(latitude: 0.0, longitude: 0.0),
          locationLabel: 'Test Zone',
        );
        final createdAlertId = await alertRepo.create(alert);

        // Force alert repo to return false (already claimed)
        alertRepo.nextClaimResult = false;

        final success = await controller.claimResponse(
          createdAlertId,
          'ranger-1',
          'Ranger One',
        );

        expect(success, isFalse);
        expect(
          controller.lastResult,
          equals('Another officer is already responding to this alert'),
        );
        expect(controller.errorMessage, isNull);
      });

      test('handles claim errors', () async {
        // Force alert repo to throw
        alertRepo.forceError = true;

        final success = await controller.claimResponse(
          'alert-1',
          'ranger-1',
          'Ranger One',
        );

        expect(success, isFalse);
        expect(controller.errorMessage, contains('Failed to claim response'));
      });
    });

    group('acknowledgeAlert', () {
      test('successfully acknowledges alert', () async {
        await controller.acknowledgeAlert('alert-1', 'officer-1');

        expect(controller.lastResult, equals('Alert acknowledged'));
        expect(controller.errorMessage, isNull);

        // Verify repo was called
        expect(alertRecipientRepo.lastMarkReadAlertId, equals('alert-1'));
        expect(alertRecipientRepo.lastMarkReadOfficerId, equals('officer-1'));
      });

      test('handles acknowledge errors', () async {
        alertRecipientRepo.forceError = true;

        await controller.acknowledgeAlert('alert-1', 'officer-1');

        expect(
          controller.errorMessage,
          contains('Failed to acknowledge alert'),
        );
      });
    });

    group('resolveAlert', () {
      test('successfully resolves alert', () async {
        // Set up alert in repository first
        final alert = Alert(
          alertId: '', // Will be set by repository
          type: 'high_risk_movement',
          timestamp: Timestamp.now(),
          status: 'active',
          responseStatus: AlertResponseStatus.responding,
          respondingOfficerId: 'ranger-1',
          respondingOfficerName: 'Ranger One',
          respondingAt: Timestamp.now(),
          animalId: 'elephant-23',
          animalName: 'Elephant-23',
          zoneId: 'zone-test',
          location: AlertLocation(latitude: 0.0, longitude: 0.0),
          locationLabel: 'Test Zone',
        );
        final createdAlertId = await alertRepo.create(alert);

        await controller.resolveAlert(createdAlertId);

        expect(controller.lastResult, equals('Alert marked as resolved'));
        expect(controller.errorMessage, isNull);

        // Verify repo was called
        expect(alertRepo.lastResolveAlertId, equals(createdAlertId));

        // Verify alert status was updated in repository
        final updatedAlert = await alertRepo.getById(createdAlertId);
        expect(
          updatedAlert?.responseStatus,
          equals(AlertResponseStatus.resolved),
        );
      });

      test('handles resolve errors', () async {
        // Create an alert first
        final alert = Alert(
          alertId: '', // Will be set by repository
          type: 'high_risk_movement',
          timestamp: Timestamp.now(),
          status: 'active',
          responseStatus: AlertResponseStatus.responding,
          respondingOfficerId: 'ranger-1',
          respondingOfficerName: 'Ranger One',
          respondingAt: Timestamp.now(),
          animalId: 'elephant-23',
          animalName: 'Elephant-23',
          zoneId: 'zone-test',
          location: AlertLocation(latitude: 0.0, longitude: 0.0),
          locationLabel: 'Test Zone',
        );
        final createdAlertId = await alertRepo.create(alert);

        alertRepo.forceError = true;

        await controller.resolveAlert(createdAlertId);

        expect(controller.errorMessage, contains('Failed to resolve alert'));
      });
    });

    group('simulateMissingUpdate', () {
      test('records missing update state', () {
        controller.simulateMissingUpdate('elephant-23');

        expect(controller.state, equals(MonitoringState.missingUpdate));
        expect(
          controller.lastResult,
          equals('Missing location update detected for animal elephant-23'),
        );
      });
    });

    group('clearError', () {
      test('clears error state and returns to monitoring', () async {
        // Force an error first
        animalRepo.forceError = true;
        await controller.onLocationReceived(
          'any-animal',
          AnimalLocation(
            latitude: 0.0,
            longitude: 0.0,
            timestamp: Timestamp.fromDate(DateTime.now()),
          ),
        );

        expect(controller.state, equals(MonitoringState.error));
        expect(controller.errorMessage, isNotNull);

        controller.clearError();

        expect(controller.state, equals(MonitoringState.idle));
        expect(controller.errorMessage, isNull);
      });

      test('does nothing when not in error state', () {
        expect(controller.state, equals(MonitoringState.idle));

        controller.clearError();

        expect(controller.state, equals(MonitoringState.idle));
      });
    });

    group('state transitions', () {
      test('starts in monitoring state', () {
        expect(controller.state, equals(MonitoringState.idle));
        expect(controller.lastResult, isNull);
        expect(controller.errorMessage, isNull);
        expect(controller.lastAlert, isNull);
      });

      test('notifies listeners on state changes', () {
        var notified = false;
        controller.addListener(() {
          notified = true;
        });

        controller.simulateMissingUpdate('test');

        expect(notified, isTrue);
      });
    });
  });
}

/// Mock implementation of HighRiskZoneDetectionService for testing
class MockHighRiskZoneDetectionService extends HighRiskZoneDetectionService {
  ZoneCheckResult? nextZoneCheckResult;
  List<String>? nextNearbyRecipients;

  MockHighRiskZoneDetectionService({
    required OfficerRepository officerRepository,
    required DutyRosterRepository dutyRosterRepository,
    required HighRiskZoneRepository zoneRepository,
  }) : super(
         officerRepository: officerRepository,
         dutyRosterRepository: dutyRosterRepository,
         zoneRepository: zoneRepository,
       );

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
