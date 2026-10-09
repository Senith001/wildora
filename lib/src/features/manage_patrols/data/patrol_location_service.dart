import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'patrol_models.dart';

/// Provides GPS location tracking for patrols.
///
/// On native platforms uses [Geolocator]. On web or in tests an injectable
/// [positionReader] can be supplied. If GPS is unavailable, methods throw
/// rather than fabricating positions.
class PatrolLocationService {
  PatrolLocationService({this.positionReader});

  /// Optional injectable position reader for testing / web fallback.
  final Future<Position> Function()? positionReader;

  StreamSubscription<Position>? _trackingSubscription;
  bool _isTracking = false;

  bool get isTracking => _isTracking;

  /// Request a single GPS fix and return a [TrackPoint].
  ///
  /// Throws on permission denial, timeout, or unavailable services.
  Future<TrackPoint> captureCurrentPosition() async {
    final position = await _readPosition();
    return TrackPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: position.timestamp,
      accuracy: position.accuracy,
      source: LocationSource.gps,
    );
  }

  /// Start continuous GPS tracking that calls [onPoint] for each valid fix.
  ///
  /// Returns immediately. Tracking stops when [stopTracking] is called.
  void startTracking(void Function(TrackPoint) onPoint) {
    if (_isTracking) return;
    _isTracking = true;

    if (positionReader != null) {
      // Simulated mode: poll every 5 seconds.
      _trackingSubscription = Stream.periodic(
        const Duration(seconds: 5),
      ).asyncMap((_) => positionReader!()).listen(
        (position) {
          onPoint(TrackPoint(
            latitude: position.latitude,
            longitude: position.longitude,
            timestamp: position.timestamp,
            accuracy: position.accuracy,
            source: LocationSource.gps,
          ));
        },
        onError: (_) {
          // GPS error during tracking – silently skip this fix.
        },
      );
    } else {
      // Native Geolocator streaming.
      const settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // metres between updates
      );
      _trackingSubscription = Geolocator.getPositionStream(
        locationSettings: settings,
      ).listen(
        (position) {
          onPoint(TrackPoint(
            latitude: position.latitude,
            longitude: position.longitude,
            timestamp: position.timestamp,
            accuracy: position.accuracy,
            source: LocationSource.gps,
          ));
        },
        onError: (_) {
          // GPS error during tracking – silently skip.
        },
      );
    }
  }

  /// Stop continuous GPS tracking.
  void stopTracking() {
    _isTracking = false;
    _trackingSubscription?.cancel();
    _trackingSubscription = null;
  }

  /// Release resources.
  void dispose() {
    stopTracking();
  }

  Future<Position> _readPosition() async {
    if (positionReader != null) {
      return positionReader!();
    }
    if (kIsWeb) {
      throw StateError('GPS not available in web mode without injected reader.');
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationServiceDisabledException();
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const PermissionDeniedException(
        'Allow location access in device settings.',
      );
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 30),
      ),
    );
  }
}
