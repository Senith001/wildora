// Monitor Wildlife and Respond to Risk Alerts — Controller & Notifications suite.
//
// Covers the AnimalMonitoringController orchestration sequence and the
// NotificationService FCM client path. Defines LOCAL mocks for the detection
// service and the messaging wrapper so each scenario is deterministic, and
// reuses the shared in-memory fakes. Independent of the old test folder.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wildora/src/data/models/alert.dart';
import 'package:wildora/src/data/models/alert_recipient.dart';
import 'package:wildora/src/data/models/animal.dart';
import 'package:wildora/src/data/models/high_risk_zone.dart';
import 'package:wildora/src/features/high_risk_movement/application/animal_monitoring_controller.dart';
import 'package:wildora/src/features/high_risk_movement/application/high_risk_zone_detection_service.dart';
import 'package:wildora/src/features/high_risk_movement/application/messaging_wrapper.dart';
import 'package:wildora/src/features/high_risk_movement/application/notification_service.dart';
import 'package:wildora/src/features/high_risk_movement/domain/geo.dart';
import 'package:wildora/src/features/high_risk_movement/domain/monitoring_state.dart';
import 'package:wildora/src/features/high_risk_movement/domain/zone_check_result.dart';

import '../fakes/in_memory_repositories.dart';

/// Local stubbable detection service. Overrides checkZones/resolveNearbyRecipients
/// with injectable fields so the controller flow is deterministic without real
/// geometry. Shape copied (not imported) from the existing controller tests.
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

/// Local fake MessagingWrapper with simulate* helpers for driving FCM streams.
class MockMessagingWrapper implements MessagingWrapper {
  bool requestPermissionCalled = false;
  bool getTokenCalled = false;
  bool forceError = false;

  NotificationSettings? nextPermissionResult;
  String? nextToken;
  RemoteMessage? nextInitialMessage;

  final StreamController<String> _tokenRefreshController =
      StreamController<String>.broadcast();
  final StreamController<RemoteMessage> _foregroundController =
      StreamController<RemoteMessage>.broadcast();
  final StreamController<RemoteMessage> _messageOpenedController =
      StreamController<RemoteMessage>.broadcast();

  @override
  Future<NotificationSettings> requestPermission({
    bool alert = true,
    bool badge = true,
    bool sound = true,
  }) async {
    if (forceError) throw Exception('Mock error');
    requestPermissionCalled = true;
    return nextPermissionResult ?? _denied();
  }

  @override
  Future<String?> getToken() async {
    if (forceError) throw Exception('Mock error');
    getTokenCalled = true;
    return nextToken;
  }

  @override
  Future<RemoteMessage?> getInitialMessage() async {
    if (forceError) throw Exception('Mock error');
    return nextInitialMessage;
  }

  @override
  Stream<String> get onTokenRefresh => _tokenRefreshController.stream;

  @override
  Stream<RemoteMessage> get onMessage => _foregroundController.stream;

  @override
  Stream<RemoteMessage> get onMessageOpenedApp =>
      _messageOpenedController.stream;

  void simulateTokenRefresh(String newToken) =>
      _tokenRefreshController.add(newToken);

  void simulateForegroundMessage(RemoteMessage message) =>
      _foregroundController.add(message);

  void simulateMessageOpenedApp(RemoteMessage message) =>
      _messageOpenedController.add(message);

  void dispose() {
    _tokenRefreshController.close();
    _foregroundController.close();
    _messageOpenedController.close();
  }
}

/// Helper that builds an authorized/granted NotificationSettings.
NotificationSettings _granted() => const NotificationSettings(
  authorizationStatus: AuthorizationStatus.authorized,
  alert: AppleNotificationSetting.enabled,
  badge: AppleNotificationSetting.enabled,
  sound: AppleNotificationSetting.enabled,
  announcement: AppleNotificationSetting.notSupported,
  carPlay: AppleNotificationSetting.notSupported,
  criticalAlert: AppleNotificationSetting.notSupported,
  providesAppNotificationSettings: AppleNotificationSetting.notSupported,
  lockScreen: AppleNotificationSetting.enabled,
  notificationCenter: AppleNotificationSetting.enabled,
  showPreviews: AppleShowPreviewSetting.always,
  timeSensitive: AppleNotificationSetting.notSupported,
);

/// Helper that builds a denied NotificationSettings.
NotificationSettings _denied() => const NotificationSettings(
  authorizationStatus: AuthorizationStatus.denied,
  alert: AppleNotificationSetting.disabled,
  badge: AppleNotificationSetting.disabled,
  sound: AppleNotificationSetting.disabled,
  announcement: AppleNotificationSetting.notSupported,
  carPlay: AppleNotificationSetting.notSupported,
  criticalAlert: AppleNotificationSetting.notSupported,
  providesAppNotificationSettings: AppleNotificationSetting.notSupported,
  lockScreen: AppleNotificationSetting.disabled,
  notificationCenter: AppleNotificationSetting.disabled,
  showPreviews: AppleShowPreviewSetting.never,
  timeSensitive: AppleNotificationSetting.notSupported,
);

void main() {
  // ===========================================================================
  // AnimalMonitoringController
  // ===========================================================================
  group('AnimalMonitoringController', () {
    late AnimalMonitoringController controller;
    late InMemoryAnimalRepository animalRepo;
    late InMemoryAlertRepository alertRepo;
    late InMemoryAlertRecipientRepository alertRecipientRepo;
    late InMemoryHighRiskZoneRepository zoneRepo;
    late MockHighRiskZoneDetectionService detectionService;

    // Deterministic injected time (no real clock).
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

    AnimalLocation locAt(double lat, double lng) => AnimalLocation(
      latitude: lat,
      longitude: lng,
      timestamp: Timestamp.fromDate(detectedAt),
    );

    test('starts in the idle state with empty fields', () {
      expect(controller.state, equals(MonitoringState.idle));
      expect(controller.lastResult, isNull);
      expect(controller.errorMessage, isNull);
      expect(controller.lastAlert, isNull);
    });

    group('onLocationReceived skip paths', () {
      test('animal not found => skipped, idle, and no location persisted',
          () async {
        await controller.onLocationReceived('ghost-animal', locAt(1.0, 2.0));

        expect(controller.state, equals(MonitoringState.idle));
        expect(
          controller.lastResult,
          equals('Animal ghost-animal not found - skipped'),
        );
        expect(controller.errorMessage, isNull);
        expect(await animalRepo.getById('ghost-animal'), isNull);
      });

      test('animal has no collar => skipped, idle, and no location persisted',
          () async {
        await animalRepo.create(
          const Animal(
            animalId: 'buffalo-11',
            name: 'Buffalo 11',
            species: 'Buffalo',
            collarId: null,
            currentLocation: null,
          ),
        );

        await controller.onLocationReceived('buffalo-11', locAt(1.0, 2.0));

        expect(controller.state, equals(MonitoringState.idle));
        expect(
          controller.lastResult,
          equals('Animal Buffalo 11 has no collar - skipped'),
        );
        expect(controller.errorMessage, isNull);
        final stored = await animalRepo.getById('buffalo-11');
        expect(stored?.currentLocation, isNull);
      });
    });

    test('not-in-zone => persists location and reports noAlert', () async {
      await animalRepo.create(collaredAnimal());
      detectionService.nextZoneCheckResult = ZoneCheckResult.notInZone();

      await controller.onLocationReceived('elephant-23', locAt(-1.2921, 36.8219));

      expect(controller.state, equals(MonitoringState.noAlert));
      expect(
        controller.lastResult,
        equals('Location updated for Elephant-23 - no high-risk zones detected'),
      );
      expect(controller.errorMessage, isNull);

      final updated = await animalRepo.getById('elephant-23');
      expect(updated?.currentLocation?.latitude, equals(-1.2921));
      expect(updated?.currentLocation?.longitude, equals(36.8219));
    });

    test('in-zone => creates alert and fans out with full field assertions',
        () async {
      await animalRepo.create(collaredAnimal());
      final zone = HighRiskZone(
        zoneId: 'zone-farmland-border',
        name: 'Farmland Border',
        riskLevel: 'High',
        center: GeoPoint(-1.2921, 36.8219),
        radiusMeters: 500.0,
      );
      await zoneRepo.create(zone);

      detectionService.nextZoneCheckResult = ZoneCheckResult.inZone(
        zoneId: zone.zoneId,
        distance: 250.0,
      );
      detectionService.nextNearbyRecipients = ['ranger-amara', 'clo-nimal'];

      await controller.onLocationReceivedCoordinates(
        'elephant-23',
        -1.2921,
        36.8219,
        detectedAt,
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

      // Fan-out recipients recorded on the fake.
      expect(alertRecipientRepo.lastFanOutAlertId, equals(alert.alertId));
      expect(
        alertRecipientRepo.lastFanOutOfficerIds,
        equals(['ranger-amara', 'clo-nimal']),
      );
      expect(alertRecipientRepo.lastFanOutChannels, equals(['inApp', 'fcm']));
      expect(controller.lastAlert?.alertId, equals(alert.alertId));

      // Inspect the actual stored recipient shape.
      final recipients = <AlertRecipient>[];
      final sub = alertRecipientRepo
          .watchForAlert(alert.alertId)
          .listen(recipients.addAll);
      await Future<void>.value();
      await sub.cancel();

      expect(recipients, hasLength(2));
      final first = recipients.firstWhere((r) => r.officerId == 'ranger-amara');
      expect(first.officerName, equals('Officer ranger-amara'));
      expect(first.role, equals('unknown'));
      expect(first.deliveryStatus, equals('pending'));
      expect(first.notifiedChannels, equals(['inApp', 'fcm']));
    });

    group('riskLevel snapshot + alert timestamp/status', () {
      Future<void> raiseFor(String riskLevel) async {
        await animalRepo.create(collaredAnimal());
        final zone = HighRiskZone(
          zoneId: 'zone-$riskLevel',
          name: '$riskLevel Zone',
          riskLevel: riskLevel,
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
      }

      test('High zone snapshots riskLevel "High" with active/unclaimed',
          () async {
        await raiseFor('High');
        final alert = (await alertRepo.getAll()).single;
        expect(alert.riskLevel, equals('High'));
        expect(alert.status, equals('active'));
        expect(alert.responseStatus, equals(AlertResponseStatus.unclaimed));
        expect(alert.timestamp.toDate(), equals(detectedAt));
      });

      test('Medium zone snapshots riskLevel "Medium"', () async {
        await raiseFor('Medium');
        final alert = (await alertRepo.getAll()).single;
        expect(alert.riskLevel, equals('Medium'));
        expect(alert.timestamp.toDate(), equals(detectedAt));
      });

      test('Low zone snapshots riskLevel "Low"', () async {
        await raiseFor('Low');
        final alert = (await alertRepo.getAll()).single;
        expect(alert.riskLevel, equals('Low'));
        expect(alert.timestamp.toDate(), equals(detectedAt));
      });
    });

    test('location is persisted BEFORE risk handling runs (non-seeded zone)',
        () async {
      // NOTE on expected message: when the matched zone id is NOT present in
      // zoneRepository.getAll(), production code's zones.firstWhere(...) in
      // onLocationReceivedCoordinates (before _handleHighRiskDetected) throws a
      // StateError caught by the OUTER try/catch, producing a 'Location
      // processing failed' message rather than 'Alert creation failed'. We
      // assert the ACTUAL production message. The ordering guarantee (location
      // persisted before the throw) is still fully verified. Changing this
      // production message is out of scope for this test suite.
      await animalRepo.create(collaredAnimal());
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

      final persisted = await animalRepo.getById('elephant-23');
      expect(persisted?.currentLocation, isNotNull);
      expect(persisted?.currentLocation?.latitude, equals(-1.2921));
      expect(persisted?.currentLocation?.longitude, equals(36.8219));

      expect(controller.state, equals(MonitoringState.error));
      expect(controller.errorMessage, contains('Location processing failed'));
      expect(controller.lastResult, isNull);
      expect(await alertRepo.getAll(), isEmpty);
    });

    test('forced create error surfaces "Alert creation failed" with location persisted first',
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
      alertRepo.forceError = true; // create() throws inside _handleHighRiskDetected

      await controller.onLocationReceivedCoordinates(
        'elephant-23',
        -1.2921,
        36.8219,
        detectedAt,
      );

      expect((await animalRepo.getById('elephant-23'))?.currentLocation?.latitude,
          equals(-1.2921));
      expect(controller.state, equals(MonitoringState.error));
      expect(controller.errorMessage, contains('Alert creation failed'));
    });

    test('in-zone with no officers => alert created, no fan-out', () async {
      await animalRepo.create(collaredAnimal());
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
      detectionService.nextNearbyRecipients = [];

      await controller.onLocationReceivedCoordinates(
        'elephant-23',
        -1.2921,
        36.8219,
        detectedAt,
      );

      expect(controller.state, equals(MonitoringState.alertRaised));
      expect(
        controller.lastResult,
        equals(
          'Alert created for Elephant-23 in Remote Zone, but no officers available',
        ),
      );
      expect(await alertRepo.getAll(), hasLength(1));
      expect(alertRecipientRepo.lastFanOutAlertId, isNull);
    });

    test('fan-out error after alert creation => error state', () async {
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
      alertRecipientRepo.forceError = true; // fanOut throws

      await controller.onLocationReceivedCoordinates(
        'elephant-23',
        -1.2921,
        36.8219,
        detectedAt,
      );

      expect(controller.state, equals(MonitoringState.error));
      expect(controller.errorMessage, contains('Alert creation failed'));
      final alerts = await alertRepo.getAll();
      expect(alerts, hasLength(1));
      expect(alerts.first.zoneId, equals('zone-fanout'));
    });

    test('single recipient uses "Notified 1 nearby officer(s)" grammar',
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
      expect(controller.lastResult, contains('Notified 1 nearby officer(s)'));
      expect(alertRecipientRepo.lastFanOutOfficerIds, equals(['ranger-amara']));
    });

    test('onLocationReceived(AnimalLocation) delegates to the coordinates variant',
        () async {
      await animalRepo.create(collaredAnimal());
      detectionService.nextZoneCheckResult = ZoneCheckResult.notInZone();

      const lat = -1.2921;
      const lng = 36.8219;
      await controller.onLocationReceived('elephant-23', locAt(lat, lng));

      expect(controller.state, equals(MonitoringState.noAlert));
      final stored = await animalRepo.getById('elephant-23');
      expect(stored?.currentLocation?.latitude, equals(lat));
      expect(stored?.currentLocation?.longitude, equals(lng));
    });

    group('claimResponse', () {
      Future<String> seedUnclaimed() async {
        return alertRepo.create(
          Alert(
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
          ),
        );
      }

      test('successfully claims an unclaimed alert', () async {
        final alertId = await seedUnclaimed();

        final ok = await controller.claimResponse(
          alertId,
          'ranger-1',
          'Ranger One',
        );

        expect(ok, isTrue);
        expect(
          controller.lastResult,
          equals('You are now responding to this alert'),
        );
        expect(controller.errorMessage, isNull);
        expect(alertRepo.lastClaimAlertId, equals(alertId));
        expect(alertRepo.lastClaimOfficerId, equals('ranger-1'));
        expect(alertRepo.lastClaimOfficerName, equals('Ranger One'));
      });

      test('returns false when already claimed by another officer', () async {
        final alertId = await seedUnclaimed();
        alertRepo.nextClaimResult = false;

        final ok = await controller.claimResponse(
          alertId,
          'ranger-1',
          'Ranger One',
        );

        expect(ok, isFalse);
        expect(
          controller.lastResult,
          equals('Another officer is already responding to this alert'),
        );
        expect(controller.errorMessage, isNull);
      });

      test('surfaces an error when the repository throws', () async {
        alertRepo.forceError = true;

        final ok = await controller.claimResponse(
          'alert-1',
          'ranger-1',
          'Ranger One',
        );

        expect(ok, isFalse);
        expect(controller.errorMessage, contains('Failed to claim response'));
      });
    });

    group('acknowledgeAlert', () {
      test('marks an alert acknowledged', () async {
        await controller.acknowledgeAlert('alert-1', 'officer-1');

        expect(controller.lastResult, equals('Alert acknowledged'));
        expect(controller.errorMessage, isNull);
        expect(alertRecipientRepo.lastMarkReadAlertId, equals('alert-1'));
        expect(alertRecipientRepo.lastMarkReadOfficerId, equals('officer-1'));
      });

      test('surfaces an error when the repository throws', () async {
        alertRecipientRepo.forceError = true;

        await controller.acknowledgeAlert('alert-1', 'officer-1');

        expect(
          controller.errorMessage,
          contains('Failed to acknowledge alert'),
        );
      });
    });

    group('resolveAlert', () {
      Future<String> seedResponding() async {
        return alertRepo.create(
          Alert(
            alertId: '',
            type: 'high_risk_movement',
            timestamp: Timestamp.fromDate(detectedAt),
            status: 'active',
            responseStatus: AlertResponseStatus.responding,
            respondingOfficerId: 'ranger-1',
            respondingOfficerName: 'Ranger One',
            respondingAt: Timestamp.fromDate(detectedAt),
            animalId: 'elephant-23',
            animalName: 'Elephant-23',
            zoneId: 'zone-test',
            location: const AlertLocation(latitude: 0.0, longitude: 0.0),
            locationLabel: 'Test Zone',
          ),
        );
      }

      test('resolves the alert in the repository', () async {
        final alertId = await seedResponding();

        await controller.resolveAlert(alertId);

        expect(controller.lastResult, equals('Alert marked as resolved'));
        expect(controller.errorMessage, isNull);
        expect(alertRepo.lastResolveAlertId, equals(alertId));
        final updated = await alertRepo.getById(alertId);
        expect(updated?.responseStatus, equals(AlertResponseStatus.resolved));
      });

      test('surfaces an error when the repository throws', () async {
        final alertId = await seedResponding();
        alertRepo.forceError = true;

        await controller.resolveAlert(alertId);

        expect(controller.errorMessage, contains('Failed to resolve alert'));
      });
    });

    test('claim/resolve of a DIFFERENT id leaves lastAlert unchanged', () async {
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

      await controller.onLocationReceivedCoordinates(
        'elephant-23',
        -1.2921,
        36.8219,
        detectedAt,
      );
      final alertA = controller.lastAlert!;
      final alertAId = alertA.alertId;
      expect(alertA.responseStatus, equals(AlertResponseStatus.unclaimed));

      // A separate alert B exists in the repo but is not lastAlert.
      final alertBId = await alertRepo.create(
        Alert(
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
        ),
      );
      expect(alertBId, isNot(equals(alertAId)));

      expect(
        await controller.claimResponse(alertBId, 'ranger-2', 'Ranger Two'),
        isTrue,
      );
      await controller.resolveAlert(alertBId);

      expect(controller.lastAlert?.alertId, equals(alertAId));
      expect(
        controller.lastAlert?.responseStatus,
        equals(AlertResponseStatus.unclaimed),
      );
      expect(controller.lastAlert?.respondingOfficerId, isNull);
      expect(controller.lastAlert?.resolvedAt, isNull);
    });

    test('simulateMissingUpdate records the missingUpdate state', () {
      controller.simulateMissingUpdate('elephant-23');

      expect(controller.state, equals(MonitoringState.missingUpdate));
      expect(
        controller.lastResult,
        equals('Missing location update detected for animal elephant-23'),
      );
    });

    group('clearError', () {
      test('clears an error and returns to idle', () async {
        animalRepo.forceError = true;
        await controller.onLocationReceived('any-animal', locAt(0.0, 0.0));
        expect(controller.state, equals(MonitoringState.error));
        expect(controller.errorMessage, isNotNull);

        controller.clearError();

        expect(controller.state, equals(MonitoringState.idle));
        expect(controller.errorMessage, isNull);
      });

      test('is a no-op when not in an error state', () {
        expect(controller.state, equals(MonitoringState.idle));
        controller.clearError();
        expect(controller.state, equals(MonitoringState.idle));
      });
    });

    group('notifyListeners', () {
      Future<String> seedUnclaimed() async {
        return alertRepo.create(
          Alert(
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
          ),
        );
      }

      test('fires on a successful claim (true)', () async {
        final alertId = await seedUnclaimed();
        var count = 0;
        controller.addListener(() => count++);

        expect(await controller.claimResponse(alertId, 'r1', 'Ranger One'),
            isTrue);
        expect(count, greaterThan(0));
      });

      test('fires on a failed claim (false)', () async {
        final alertId = await seedUnclaimed();
        alertRepo.nextClaimResult = false;
        var count = 0;
        controller.addListener(() => count++);

        expect(await controller.claimResponse(alertId, 'r1', 'Ranger One'),
            isFalse);
        expect(count, greaterThan(0));
      });

      test('fires on resolveAlert', () async {
        final alertId = await alertRepo.create(
          Alert(
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
          ),
        );
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
        expect(controller.state, equals(before));
      });
    });
  });

  // ===========================================================================
  // NotificationService
  // ===========================================================================
  group('NotificationService', () {
    late NotificationService service;
    late InMemoryOfficerRepository officerRepo;
    late MockMessagingWrapper messaging;

    setUp(() {
      officerRepo = InMemoryOfficerRepository();
      messaging = MockMessagingWrapper();
      service = NotificationService(
        officerRepository: officerRepo,
        messaging: messaging,
      );
    });

    tearDown(() async {
      await service.dispose();
      messaging.dispose();
    });

    group('initialize', () {
      test('granted permission registers the token with the officer', () async {
        messaging.nextPermissionResult = _granted();
        messaging.nextToken = 'test-token-123';

        await service.initialize('officer-1');

        expect(messaging.requestPermissionCalled, isTrue);
        expect(messaging.getTokenCalled, isTrue);
        expect(officerRepo.lastAddTokenOfficerId, equals('officer-1'));
        expect(officerRepo.lastAddToken, equals('test-token-123'));
      });

      test('denied permission skips token registration', () async {
        messaging.nextPermissionResult = _denied();

        await service.initialize('officer-1');

        expect(messaging.requestPermissionCalled, isTrue);
        expect(messaging.getTokenCalled, isFalse);
        expect(officerRepo.lastAddTokenOfficerId, isNull);
      });

      test('a token refresh re-registers the new token', () async {
        messaging.nextPermissionResult = _granted();
        messaging.nextToken = 'initial-token';
        await service.initialize('officer-1');

        messaging.simulateTokenRefresh('refreshed-token-456');
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(officerRepo.tokenRegistrations, hasLength(2));
        expect(officerRepo.tokenRegistrations.last.token,
            equals('refreshed-token-456'));
        expect(officerRepo.tokenRegistrations.last.officerId, equals('officer-1'));
      });

      test('an initialization error is rethrown', () async {
        messaging.forceError = true;

        expect(() => service.initialize('officer-1'), throwsException);
      });
    });

    group('getCurrentToken', () {
      test('returns the current token', () async {
        messaging.nextToken = 'current-token-789';

        final token = await service.getCurrentToken();

        expect(token, equals('current-token-789'));
        expect(messaging.getTokenCalled, isTrue);
      });

      test('returns null when token retrieval fails', () async {
        messaging.forceError = true;

        expect(await service.getCurrentToken(), isNull);
      });
    });

    test('token registration failure is swallowed (no rethrow)', () async {
      officerRepo.forceError = true; // addFcmToken throws
      messaging.nextPermissionResult = _granted();
      messaging.nextToken = 'test-token';

      // Should complete without throwing despite the repository failure.
      await service.initialize('officer-1');

      expect(messaging.getTokenCalled, isTrue);
    });

    test('dispose cleans up without throwing', () async {
      messaging.nextPermissionResult = _granted();
      messaging.nextToken = 'test-token';
      await service.initialize('officer-1');

      await service.dispose();

      // A second dispose is still safe.
      await service.dispose();
    });

    // Smoke check: a single minimal test covering both message handler streams.
    test('delivers foreground + opened messages without throwing (smoke check)',
        () async {
      messaging.nextPermissionResult = _granted();
      messaging.nextToken = 'test-token';
      await service.initialize('officer-1');

      messaging.simulateForegroundMessage(
        const RemoteMessage(
          messageId: 'msg-1',
          data: {'alertId': 'alert-123', 'type': 'high_risk_movement'},
          notification: RemoteNotification(
            title: 'High-Risk Alert',
            body: 'Elephant-23 entered Farmland Border',
          ),
        ),
      );
      messaging.simulateMessageOpenedApp(
        const RemoteMessage(messageId: 'msg-2', data: {'alertId': 'alert-456'}),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // No exceptions propagated from the handlers.
      expect(true, isTrue);
    });
  });
}
