import 'package:geolocator/geolocator.dart';
import 'package:wildora/src/features/manage_patrols/data/patrol_location_service.dart';
import 'package:wildora/src/features/manage_patrols/data/patrol_models.dart';

/// Fake location service that returns controllable positions for tests.
class FakePatrolLocationService extends PatrolLocationService {
  FakePatrolLocationService() : super(positionReader: null);

  Position? nextPosition;
  bool shouldFail = false;
  void Function(TrackPoint)? _trackingCallback;
  bool trackingStarted = false;

  @override
  Future<TrackPoint> captureCurrentPosition() async {
    if (shouldFail) {
      throw StateError('GPS unavailable');
    }
    final pos = nextPosition ??
        Position(
          latitude: 6.9271,
          longitude: 79.8612,
          timestamp: DateTime.now(),
          accuracy: 5.0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
    return TrackPoint(
      latitude: pos.latitude,
      longitude: pos.longitude,
      timestamp: pos.timestamp,
      accuracy: pos.accuracy,
      source: LocationSource.gps,
    );
  }

  @override
  Future<void> startTracking(void Function(TrackPoint) onPoint) async {
    trackingStarted = true;
    _trackingCallback = onPoint;
  }

  /// Simulate a GPS fix during tracking.
  void simulateGpsFix(TrackPoint point) {
    _trackingCallback?.call(point);
  }

  @override
  void stopTracking() {
    trackingStarted = false;
    _trackingCallback = null;
  }

  @override
  void dispose() {
    stopTracking();
  }
}
