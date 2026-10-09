import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:wildora/src/data/models/animal.dart';
import 'package:wildora/src/data/models/alert.dart';
import 'package:wildora/src/data/models/alert_recipient.dart';
import 'package:wildora/src/data/models/duty_roster.dart';
import 'package:wildora/src/data/models/high_risk_zone.dart';
import 'package:wildora/src/data/models/officer.dart';
import 'package:wildora/src/data/models/user_preferences.dart';
import 'package:wildora/src/data/repositories/animal_repository.dart';
import 'package:wildora/src/data/repositories/alert_recipient_repository.dart';
import 'package:wildora/src/data/repositories/alert_repository.dart';
import 'package:wildora/src/data/repositories/duty_roster_repository.dart';
import 'package:wildora/src/data/repositories/high_risk_zone_repository.dart';
import 'package:wildora/src/data/repositories/officer_repository.dart';
import 'package:wildora/src/data/repositories/user_preferences_repository.dart';

/// In-memory implementation of AnimalRepository for testing.
///
/// Uses Map storage and supports all interface operations without Firebase.
class InMemoryAnimalRepository implements AnimalRepository {
  final Map<String, Animal> _animals = {};
  bool forceError = false;

  void seed(List<Animal> animals) {
    _animals.clear();
    for (final animal in animals) {
      _animals[animal.animalId] = animal;
    }
  }

  void dispose() {
    // Clean up any resources if needed
    _animals.clear();
  }

  Future<void> create(Animal animal) async {
    if (forceError) throw Exception('Forced error');
    _animals[animal.animalId] = animal;
  }

  @override
  Future<Animal?> getById(String animalId) async {
    if (forceError) throw Exception('Forced error');
    return _animals[animalId];
  }

  @override
  Future<void> updateCurrentLocation(
    String animalId,
    AnimalLocation location,
  ) async {
    if (forceError) throw Exception('Forced error');
    final animal = _animals[animalId];
    if (animal == null) {
      throw Exception('Animal not found: $animalId');
    }

    _animals[animalId] = Animal(
      animalId: animal.animalId,
      species: animal.species,
      name: animal.name,
      collarId: animal.collarId,
      currentLocation: location,
    );
  }

  @override
  Future<List<Animal>> getAll() async {
    return _animals.values.toList();
  }
}

/// In-memory implementation of HighRiskZoneRepository for testing.
class InMemoryHighRiskZoneRepository implements HighRiskZoneRepository {
  final Map<String, HighRiskZone> _zones = {};

  void seed(List<HighRiskZone> zones) {
    _zones.clear();
    for (final zone in zones) {
      _zones[zone.zoneId] = zone;
    }
  }

  void dispose() {
    _zones.clear();
  }

  Future<void> create(HighRiskZone zone) async {
    _zones[zone.zoneId] = zone;
  }

  @override
  Future<List<HighRiskZone>> getAll() async {
    return _zones.values.toList();
  }

  @override
  Future<HighRiskZone?> getById(String zoneId) async {
    return _zones[zoneId];
  }
}

/// In-memory implementation of AlertRepository for testing.
///
/// Supports atomic claim response simulation and real-time streams via StreamController.
class InMemoryAlertRepository implements AlertRepository {
  final Map<String, Alert> _alerts = {};
  final StreamController<List<Alert>> _activeAlertsController =
      StreamController<List<Alert>>.broadcast();
  final StreamController<List<Alert>> _alertsController =
      StreamController<List<Alert>>.broadcast();
  final Map<String, StreamController<Alert?>> _alertByIdControllers = {};
  int _nextId = 1;

  // Test support properties
  bool forceError = false;
  bool nextClaimResult = true;
  String? lastClaimAlertId;
  String? lastClaimOfficerId;
  String? lastClaimOfficerName;
  String? lastResolveAlertId;

  // Track method calls for testing
  final List<Map<String, dynamic>> claimResponseCalls = [];
  final List<String> acknowledgeAlertCalls = [];
  final List<String> resolveResponseCalls = [];

  // Mock data for testing
  List<Alert>? _mockActiveAlerts;
  String? _mockError;

  void seed(List<Alert> alerts) {
    _alerts.clear();
    for (final alert in alerts) {
      _alerts[alert.alertId] = alert;
    }
    _emitAlertsUpdate();
  }

  /// Set mock active alerts for testing
  void setMockActiveAlerts(List<Alert> alerts) {
    _mockActiveAlerts = alerts;
    _activeAlertsController.add(alerts);
  }

  /// Set mock error for testing
  void setMockError(String error) {
    _mockError = error;
  }

  /// Set up a single alert for testing (replaces setMockAlert)
  void setupAlert(String alertId, Alert? alert) {
    if (alert != null) {
      _alerts[alertId] = alert;
      _emitAlertsUpdate();
      _emitAlertByIdUpdate(alertId);
    } else {
      _alerts.remove(alertId);
      _emitAlertsUpdate();
      _emitAlertByIdUpdate(alertId);
    }
  }

  void dispose() {
    _activeAlertsController.close();
    for (final controller in _alertByIdControllers.values) {
      controller.close();
    }
    _alertByIdControllers.clear();
  }

  void _emitAlertsUpdate() {
    if (_mockActiveAlerts != null) {
      _activeAlertsController.add(_mockActiveAlerts!);
    } else {
      final activeAlerts = _alerts.values
          .where((alert) => alert.status == 'active')
          .toList();
      _activeAlertsController.add(activeAlerts);
    }

    // Also emit to alerts controller for streamAlerts
    final allAlerts = _alerts.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    _alertsController.add(allAlerts);
  }

  void _emitAlertByIdUpdate(String alertId) {
    final controller = _alertByIdControllers[alertId];
    if (controller != null) {
      if (_mockError != null) {
        controller.addError(Exception(_mockError));
      } else {
        controller.add(_alerts[alertId]);
      }
    }
  }

  @override
  Future<String> create(Alert alert) async {
    if (forceError) throw Exception('Forced error');

    final alertId = 'alert_${_nextId++}';
    final alertWithId = Alert(
      alertId: alertId,
      type: alert.type,
      timestamp: alert.timestamp,
      status: alert.status,
      responseStatus: alert.responseStatus,
      respondingOfficerId: alert.respondingOfficerId,
      respondingOfficerName: alert.respondingOfficerName,
      respondingAt: alert.respondingAt,
      animalId: alert.animalId,
      zoneId: alert.zoneId,
      location: alert.location,
      animalName: alert.animalName,
      locationLabel: alert.locationLabel,
    );

    _alerts[alertId] = alertWithId;
    _emitAlertsUpdate();
    return alertId;
  }

  @override
  Stream<List<Alert>> watchActiveAlerts() {
    // Return mock data if available, otherwise use real data
    return Stream.multi((controller) {
      if (_mockError != null) {
        controller.addError(Exception(_mockError!));
        return;
      }

      if (_mockActiveAlerts != null) {
        controller.add(_mockActiveAlerts!);
      } else {
        // Emit current state immediately
        final current =
            _alerts.values.where((alert) => alert.status == 'active').toList()
              ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        controller.add(current);
      }

      // Listen for future updates
      late StreamSubscription subscription;
      subscription = _activeAlertsController.stream.listen((alerts) {
        controller.add(alerts);
      }, onError: controller.addError);

      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Stream<List<Alert>> streamAlerts() {
    // Create a stream that emits current state immediately, then listens for updates
    return Stream.multi((controller) {
      // Emit current state immediately
      final current = _alerts.values.toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      controller.add(current);

      // Listen for future updates
      late StreamSubscription subscription;
      subscription = _alertsController.stream.listen((alerts) {
        final sortedAlerts = alerts.toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        controller.add(sortedAlerts);
      }, onError: controller.addError);

      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Future<Alert?> getById(String alertId) async {
    return _alerts[alertId];
  }

  // Additional method for testing
  Future<List<Alert>> getAll() async {
    return _alerts.values.toList();
  }

  @override
  Stream<Alert?> watchById(String alertId) {
    _alertByIdControllers.putIfAbsent(
      alertId,
      () => StreamController<Alert?>.broadcast(),
    );

    return Stream.multi((controller) {
      // Check for mock error first
      if (_mockError != null) {
        controller.addError(Exception(_mockError));
        return;
      }

      // Emit current state immediately
      controller.add(_alerts[alertId]);

      // Listen for future updates
      late StreamSubscription subscription;
      subscription = _alertByIdControllers[alertId]!.stream.listen((alert) {
        controller.add(alert);
      }, onError: controller.addError);

      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Future<bool> claimResponse(
    String alertId,
    String officerId,
    String officerName,
  ) async {
    if (forceError) throw Exception('Forced error');

    // Track call for testing
    claimResponseCalls.add({
      'alertId': alertId,
      'officerId': officerId,
      'officerName': officerName,
    });

    lastClaimAlertId = alertId;
    lastClaimOfficerId = officerId;
    lastClaimOfficerName = officerName;

    final alert = _alerts[alertId];
    if (alert == null) {
      throw Exception('Alert not found');
    }

    // Return predefined result for testing
    if (!nextClaimResult) {
      return false;
    }

    // Simulate atomic transaction - only claim if unclaimed
    if (alert.responseStatus != 'unclaimed') {
      return false; // Already claimed
    }

    // Claim the response
    _alerts[alertId] = alert.copyWith(
      responseStatus: 'responding',
      respondingOfficerId: officerId,
      respondingOfficerName: officerName,
      respondingAt: Timestamp.now(),
    );

    _emitAlertsUpdate();
    _emitAlertByIdUpdate(alertId);
    return true;
  }

  @override
  Future<void> acknowledge(String alertId) async {
    acknowledgeAlertCalls.add(alertId);

    final alert = _alerts[alertId];
    if (alert == null) {
      throw Exception('Alert not found');
    }

    _alerts[alertId] = alert.copyWith(status: 'acknowledged');
    _emitAlertsUpdate();
    _emitAlertByIdUpdate(alertId);
  }

  @override
  Future<void> resolveResponse(String alertId) async {
    if (forceError) throw Exception('Forced error');

    resolveResponseCalls.add(alertId);
    lastResolveAlertId = alertId; // Track for testing

    final alert = _alerts[alertId];
    if (alert == null) {
      throw Exception('Alert not found');
    }

    _alerts[alertId] = alert.copyWith(responseStatus: 'resolved');
    _emitAlertsUpdate();
    _emitAlertByIdUpdate(alertId);
  }
}

/// In-memory implementation of AlertRecipientRepository for testing.
class InMemoryAlertRecipientRepository implements AlertRecipientRepository {
  final Map<String, Map<String, AlertRecipient>> _recipients =
      {}; // alertId -> {officerId -> recipient}
  final StreamController<List<AlertRecipient>> _recipientsController =
      StreamController<List<AlertRecipient>>.broadcast();

  // Test support properties
  bool forceError = false;
  String? lastFanOutAlertId;
  List<String>? lastFanOutOfficerIds;
  List<String>? lastFanOutChannels;
  String? lastMarkReadAlertId;
  String? lastMarkReadOfficerId;

  void seed(String alertId, List<AlertRecipient> recipients) {
    _recipients[alertId] = {};
    for (final recipient in recipients) {
      _recipients[alertId]![recipient.officerId] = recipient;
    }
    _emitRecipientsUpdate();
  }

  void dispose() {
    _recipientsController.close();
  }

  void _emitRecipientsUpdate() {
    final allRecipients = _recipients.values
        .expand((map) => map.values)
        .toList();
    _recipientsController.add(allRecipients);
  }

  @override
  Future<void> fanOut(String alertId, List<AlertRecipient> recipients) async {
    if (forceError) throw Exception('Forced error');

    if (recipients.isEmpty) return;

    // Track for testing
    lastFanOutAlertId = alertId;
    lastFanOutOfficerIds = recipients.map((r) => r.officerId).toList();
    lastFanOutChannels = recipients.isNotEmpty
        ? recipients.first.notifiedChannels
        : null;

    _recipients[alertId] = {};
    for (final recipient in recipients) {
      _recipients[alertId]![recipient.officerId] = recipient;
    }
    _emitRecipientsUpdate();
  }

  // Convenience method for testing with officer IDs and channels
  Future<void> fanOutToOfficers(
    String alertId,
    List<String> officerIds, {
    List<String> notifiedChannels = const ['inApp'],
  }) async {
    if (forceError) throw Exception('Forced error');

    // Track for testing
    lastFanOutAlertId = alertId;
    lastFanOutOfficerIds = officerIds;
    lastFanOutChannels = notifiedChannels;

    final recipients = officerIds
        .map(
          (officerId) => AlertRecipient(
            officerId: officerId,
            officerName: 'Officer $officerId', // Mock name
            role: 'ranger', // Mock role
            deliveryStatus: 'pending',
            readAt: null,
            notifiedChannels: notifiedChannels,
          ),
        )
        .toList();

    await fanOut(alertId, recipients);
  }

  @override
  Stream<List<AlertRecipient>> watchRecipientsForOfficer(String officerId) {
    return Stream.multi((controller) {
      // Emit current state immediately
      final allRecipients = _recipients.values
          .expand((map) => map.values)
          .toList();
      final current = allRecipients
          .where((r) => r.officerId == officerId)
          .toList();
      controller.add(current);

      // Listen for future updates
      late StreamSubscription subscription;
      subscription = _recipientsController.stream.listen((allRecipients) {
        final filtered = allRecipients
            .where((r) => r.officerId == officerId)
            .toList();
        controller.add(filtered);
      }, onError: controller.addError);

      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Stream<List<AlertRecipient>> watchForAlert(String alertId) {
    return Stream.multi((controller) {
      // Emit current state immediately
      final current = _recipients[alertId]?.values.toList() ?? [];
      controller.add(current);

      // Listen for future updates
      late StreamSubscription subscription;
      subscription = _recipientsController.stream.listen((allRecipients) {
        final alertRecipients = _recipients[alertId]?.values.toList() ?? [];
        controller.add(alertRecipients);
      }, onError: controller.addError);

      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Future<void> markRead(String alertId, String officerId) async {
    if (forceError) throw Exception('Forced error');

    // Track for testing
    lastMarkReadAlertId = alertId;
    lastMarkReadOfficerId = officerId;

    final alertRecipients = _recipients[alertId];
    if (alertRecipients == null) return;

    final recipient = alertRecipients[officerId];
    if (recipient == null) return;

    alertRecipients[officerId] = recipient.copyWith(
      deliveryStatus: 'read',
      readAt: Timestamp.now(),
    );
    _emitRecipientsUpdate();
  }
}

/// In-memory implementation of OfficerRepository for testing.
class InMemoryOfficerRepository implements OfficerRepository {
  final Map<String, Officer> _officers = {};

  // Test support properties
  bool forceError = false;
  String? lastAddTokenOfficerId;
  String? lastAddToken;
  final List<TokenRegistration> tokenRegistrations = [];

  void seed(List<Officer> officers) {
    _officers.clear();
    for (final officer in officers) {
      _officers[officer.officerId] = officer;
    }
  }

  void dispose() {
    _officers.clear();
    tokenRegistrations.clear();
  }

  Future<void> create(Officer officer) async {
    if (forceError) throw Exception('Forced error');
    _officers[officer.officerId] = officer;
  }

  @override
  Future<List<Officer>> getAll() async {
    return _officers.values.toList();
  }

  @override
  Future<List<Officer>> getByRole(String role) async {
    return _officers.values.where((o) => o.role == role).toList();
  }

  @override
  Future<void> addFcmToken(String officerId, String token) async {
    if (forceError) throw Exception('Forced error');

    // Track for testing
    lastAddTokenOfficerId = officerId;
    lastAddToken = token;
    tokenRegistrations.add(TokenRegistration(officerId, token));

    final officer = _officers[officerId];
    if (officer == null) {
      throw Exception('Officer not found: $officerId');
    }

    final updatedTokens = List<String>.from(officer.fcmTokens);
    if (!updatedTokens.contains(token)) {
      updatedTokens.add(token);
    }

    _officers[officerId] = officer.copyWith(fcmTokens: updatedTokens);
  }

  @override
  Future<void> removeFcmToken(String officerId, String token) async {
    final officer = _officers[officerId];
    if (officer == null) {
      throw Exception('Officer not found: $officerId');
    }

    final updatedTokens = List<String>.from(officer.fcmTokens)..remove(token);
    _officers[officerId] = officer.copyWith(fcmTokens: updatedTokens);
  }

  @override
  Future<void> updateLocation(
    String officerId,
    GeoPoint location,
    Timestamp timestamp,
  ) async {
    final officer = _officers[officerId];
    if (officer == null) {
      throw Exception('Officer not found: $officerId');
    }

    _officers[officerId] = officer.copyWith(
      location: location,
      locationUpdatedAt: timestamp,
    );
  }
}

/// In-memory implementation of DutyRosterRepository for testing.
class InMemoryDutyRosterRepository implements DutyRosterRepository {
  final Map<String, DutyRoster> _rosters = {}; // date -> roster

  void seed(List<DutyRoster> rosters) {
    _rosters.clear();
    for (final roster in rosters) {
      _rosters[roster.date] = roster;
    }
  }

  void dispose() {
    _rosters.clear();
  }

  Future<void> setByDate(String date, DutyRoster roster) async {
    _rosters[date] = roster;
  }

  @override
  Future<DutyRoster?> getByDate(String date) async {
    return _rosters[date];
  }
}

/// In-memory implementation of UserPreferencesRepository for testing.
class InMemoryUserPreferencesRepository implements UserPreferencesRepository {
  final Map<String, UserPreferences> _preferences = {};
  final StreamController<String?> _themeController =
      StreamController<String?>.broadcast();

  // Test support
  bool forceError = false;

  void seed(List<UserPreferences> preferences) {
    _preferences.clear();
    for (final pref in preferences) {
      _preferences[pref.userId] = pref;
    }
  }

  void dispose() {
    _themeController.close();
  }

  @override
  Future<String?> getThemeMode(String userId) async {
    if (forceError) throw Exception('Forced error');
    return _preferences[userId]?.themeMode;
  }

  @override
  Stream<String?> watchThemeMode(String userId) {
    return Stream.multi((controller) {
      // Emit current state immediately
      final current = _preferences[userId]?.themeMode;
      controller.add(current);

      // Listen for future updates
      late StreamSubscription subscription;
      subscription = _themeController.stream.listen((themeMode) {
        controller.add(themeMode);
      }, onError: controller.addError);

      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Future<void> setThemeMode(String userId, String mode) async {
    if (forceError) throw Exception('Forced error');
    _preferences[userId] = UserPreferences(
      userId: userId,
      themeMode: mode,
      lastUpdated: Timestamp.now(),
    );
    _themeController.add(mode);
  }
}

/// Helper class to track token registrations in tests
class TokenRegistration {
  final String officerId;
  final String token;

  TokenRegistration(this.officerId, this.token);
}
