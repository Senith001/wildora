import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../data/models/alert.dart';
import '../../../data/models/alert_recipient.dart';
import '../../../data/models/animal.dart';
import '../../../data/repositories/alert_repository.dart';
import '../../../data/repositories/alert_recipient_repository.dart';
import '../../../data/repositories/animal_repository.dart';
import '../../../data/repositories/high_risk_zone_repository.dart';
import '../domain/geo.dart';
import '../domain/monitoring_state.dart';
import 'high_risk_zone_detection_service.dart';

/// ChangeNotifier controller orchestrating the high-risk animal movement detection sequence.
///
/// Implements the exact sequence per plan §10:
/// 1. onLocationReceived -> getAnimal (skip if null/no collar)
/// 2. updateCurrentLocation -> checkZones
/// 3. if inZone: build Alert -> create -> resolveNearbyRecipients -> fanOut -> set alertRaised
/// 4. else: set noAlert
/// 5. Handle errors and missing updates
///
/// NO timers/polling for battery efficiency - purely reactive.
class AnimalMonitoringController extends ChangeNotifier {
  final AnimalRepository _animalRepository;
  final AlertRepository _alertRepository;
  final AlertRecipientRepository _alertRecipientRepository;
  final HighRiskZoneDetectionService _detectionService;
  final HighRiskZoneRepository _zoneRepository;

  // Current monitoring state
  MonitoringState _state = MonitoringState.idle;
  String? _lastResult;
  String? _errorMessage;

  // Most recent alert created (for UI display)
  Alert? _lastAlert;

  AnimalMonitoringController({
    required AnimalRepository animalRepository,
    required AlertRepository alertRepository,
    required AlertRecipientRepository alertRecipientRepository,
    required HighRiskZoneDetectionService detectionService,
    required HighRiskZoneRepository zoneRepository,
  }) : _animalRepository = animalRepository,
       _alertRepository = alertRepository,
       _alertRecipientRepository = alertRecipientRepository,
       _detectionService = detectionService,
       _zoneRepository = zoneRepository;

  // Getters for UI
  MonitoringState get state => _state;
  String? get lastResult => _lastResult;
  String? get errorMessage => _errorMessage;
  Alert? get lastAlert => _lastAlert;

  /// Alert repository for UI access to streams and methods
  AlertRepository get alertRepository => _alertRepository;

  /// Main location ingestion method implementing the sequence.
  ///
  /// Called when a simulated collar location update is received.
  /// Handles the complete flow from location -> detection -> alert -> fanout.
  Future<void> onLocationReceived(
    String animalId,
    AnimalLocation location,
  ) async {
    return onLocationReceivedCoordinates(
      animalId,
      location.latitude,
      location.longitude,
      location.timestamp.toDate(),
    );
  }

  /// Main location ingestion method with individual coordinates.
  ///
  /// Called when a simulated collar location update is received.
  /// Handles the complete flow from location -> detection -> alert -> fanout.
  Future<void> onLocationReceivedCoordinates(
    String animalId,
    double latitude,
    double longitude,
    DateTime timestamp,
  ) async {
    _setState(MonitoringState.processing);
    _clearError();

    try {
      // Step 1: Get animal details
      final animal = await _animalRepository.getById(animalId);
      if (animal == null) {
        _setResult('Animal $animalId not found - skipped');
        _setState(MonitoringState.idle);
        return;
      }

      // Step 2: Skip if no collar
      if (animal.collarId == null) {
        _setResult('Animal ${animal.name} has no collar - skipped');
        _setState(MonitoringState.idle);
        return;
      }

      // Step 3: Update current location (always persisted)
      final newLocation = AnimalLocation(
        latitude: latitude,
        longitude: longitude,
        timestamp: Timestamp.fromDate(timestamp),
      );

      await _animalRepository.updateCurrentLocation(animalId, newLocation);

      // Step 4: Check zones
      final location = GeoPoint2D(latitude: latitude, longitude: longitude);
      final zoneCheckResult = await _detectionService.checkZones(location);

      if (zoneCheckResult.inZone && zoneCheckResult.matchedZoneId != null) {
        // Get the actual zone object for the alert
        final zones = await _zoneRepository.getAll();
        final matchedZone = zones.firstWhere(
          (z) => z.zoneId == zoneCheckResult.matchedZoneId,
        );

        // Step 5: In zone - create alert and fan out
        await _handleHighRiskDetected(
          animal,
          matchedZone,
          newLocation,
          timestamp,
        );
      } else {
        // Alternate flow: not in zone
        _setResult(
          'Location updated for ${animal.name} - no high-risk zones detected',
        );
        _setState(MonitoringState.noAlert);
      }
    } catch (e) {
      _setError('Location processing failed: $e');
      _setState(MonitoringState.error);
    }
  }

  /// Handle high-risk zone detection by creating alert and fanning out to nearby recipients.
  Future<void> _handleHighRiskDetected(
    Animal animal,
    dynamic zone, // HighRiskZone
    AnimalLocation alertLocation,
    DateTime detectedAt,
  ) async {
    try {
      // Step 6: Build alert with snapshot location
      final alert = Alert(
        alertId: '', // Will be set by repository
        type: 'high_risk_movement',
        timestamp: Timestamp.fromDate(detectedAt),
        status: 'active',
        responseStatus: AlertResponseStatus.unclaimed,
        respondingOfficerId: null,
        respondingOfficerName: null,
        respondingAt: null,
        animalId: animal.animalId,
        animalName: animal.name,
        zoneId: zone.zoneId,
        location: AlertLocation(
          latitude: alertLocation.latitude,
          longitude: alertLocation.longitude,
        ),
        locationLabel: zone.name, // Default to zone name
      );

      // Step 7: Create alert in repository
      final createdAlertId = await _alertRepository.create(alert);
      final createdAlert = alert.copyWith(alertId: createdAlertId);

      // Step 8: Resolve nearby recipients
      final nearbyRecipientIds = await _detectionService
          .resolveNearbyRecipients(
            zone.center, // GeoPoint from zone
            detectedAt,
          );

      if (nearbyRecipientIds.isEmpty) {
        _setResult(
          'Alert created for ${animal.name} in ${zone.name}, but no officers available',
        );
        _lastAlert = createdAlert;
        _setState(MonitoringState.alertRaised);
        return;
      }

      // Step 9: Fan out to nearby recipients
      final recipients = nearbyRecipientIds
          .map(
            (officerId) => AlertRecipient(
              officerId: officerId,
              officerName:
                  'Officer $officerId', // Could be looked up from officer repo
              role: 'unknown', // Could be looked up from officer repo
              deliveryStatus: 'pending',
              readAt: null,
              notifiedChannels: ['inApp', 'fcm'],
            ),
          )
          .toList();

      await _alertRecipientRepository.fanOut(createdAlertId, recipients);

      // Step 10: Update state
      _setResult(
        'HIGH-RISK ALERT: ${animal.name} entered ${zone.name}. '
        'Notified ${nearbyRecipientIds.length} nearby officer(s).',
      );
      _lastAlert = createdAlert;
      _setState(MonitoringState.alertRaised);
    } catch (e) {
      _setError('Alert creation failed: $e');
      _setState(MonitoringState.error);
    }
  }

  /// Claim response for an alert (delegates to repository transaction).
  ///
  /// Implements atomic first-responder-wins claiming.
  Future<bool> claimResponse(
    String alertId,
    String officerId,
    String officerName,
  ) async {
    try {
      _clearError();

      final success = await _alertRepository.claimResponse(
        alertId,
        officerId,
        officerName,
      );

      if (success) {
        _setResult('You are now responding to this alert');

        // Update local alert if it matches
        if (_lastAlert?.alertId == alertId) {
          _lastAlert = _lastAlert!.copyWith(
            responseStatus: AlertResponseStatus.responding,
            respondingOfficerId: officerId,
            respondingOfficerName: officerName,
            respondingAt: Timestamp.now(),
          );
        }

        notifyListeners();
        return true;
      } else {
        _setResult('Another officer is already responding to this alert');
        notifyListeners();
        return false;
      }
    } catch (e) {
      _setError('Failed to claim response: $e');
      return false;
    }
  }

  /// Acknowledge an alert (mark as read).
  Future<void> acknowledgeAlert(String alertId, String officerId) async {
    try {
      _clearError();

      await _alertRecipientRepository.markRead(alertId, officerId);
      _setResult('Alert acknowledged');
      notifyListeners();
    } catch (e) {
      _setError('Failed to acknowledge alert: $e');
    }
  }

  /// Resolve an alert (complete the response).
  Future<void> resolveAlert(String alertId) async {
    try {
      _clearError();

      await _alertRepository.resolveResponse(alertId);

      // Update local alert if it matches
      if (_lastAlert?.alertId == alertId) {
        _lastAlert = _lastAlert!.copyWith(
          responseStatus: AlertResponseStatus.resolved,
        );
      }

      _setResult('Alert marked as resolved');
      notifyListeners();
    } catch (e) {
      _setError('Failed to resolve alert: $e');
    }
  }

  /// Simulate missing update for testing exception flow.
  void simulateMissingUpdate(String animalId) {
    _setResult('Missing location update detected for animal $animalId');
    _setState(MonitoringState.missingUpdate);
  }

  /// Clear any error state and return to monitoring.
  void clearError() {
    if (_state == MonitoringState.error) {
      _clearError();
      _setState(MonitoringState.idle);
    }
  }

  // Private helpers for state management
  void _setState(MonitoringState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
    }
  }

  void _setResult(String result) {
    _lastResult = result;
  }

  void _setError(String error) {
    _errorMessage = error;
    _lastResult = null;
  }

  void _clearError() {
    _errorMessage = null;
  }
}
