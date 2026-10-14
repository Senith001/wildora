import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'patrol_models.dart';

/// Provides real-time GPS location tracking for ranger field patrols.
///
/// Supports:
/// - Native devices (Android, iOS) via hardware GPS satellites.
/// - Web browsers (Chrome, Edge) via HTML5 Geolocation API (`navigator.geolocation`).
/// - Real-time signal state stream (locating, available, stale, denied, disabled, error).
/// - Automatic initial fix acquisition on startTracking.
/// - Stale fix detection if no satellite update received for 30 seconds.
class PatrolLocationService {
  PatrolLocationService({
    this.positionReader,
    this.onStatusChanged,
  }) {
    _statusStreamController = StreamController<GpsSignalStatus>.broadcast();
  }

  /// Optional injectable position reader for unit tests.
  final Future<Position> Function()? positionReader;

  /// Optional direct status callback.
  final void Function(GpsSignalStatus status)? onStatusChanged;

  late final StreamController<GpsSignalStatus> _statusStreamController;

  /// Broadcast stream of GPS signal state changes for reactive UI updates.
  Stream<GpsSignalStatus> get signalStatusStream =>
      _statusStreamController.stream;

  StreamSubscription<Position>? _trackingSubscription;
  Timer? _staleCheckTimer;
  Timer? _simulationTimer;

  bool _isTracking = false;
  bool get isTracking => _isTracking;

  GpsSignalStatus _signalStatus = GpsSignalStatus.locating;
  GpsSignalStatus get signalStatus => _signalStatus;

  double? _lastAccuracy;
  double? get lastAccuracy => _lastAccuracy;

  DateTime? _lastFixTime;
  DateTime? get lastFixTime => _lastFixTime;

  String? _lastError;
  String? get lastError => _lastError;

  bool _isSimulationMode = false;
  bool get isSimulationMode => _isSimulationMode;

  int _simulatedStep = 0;

  /// Enable or disable development simulation walk mode (restricted to tests/dev).
  void setSimulationMode(bool enabled) {
    _isSimulationMode = enabled;
  }

  /// Request location permission with platform-appropriate feedback.
  Future<LocationPermission> checkAndRequestPermission() async {
    try {
      if (!kIsWeb) {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          _updateStatus(GpsSignalStatus.servicesDisabled);
          _lastError =
              'Location services are disabled on this device. Please turn on GPS.';
          return LocationPermission.denied;
        }
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        _updateStatus(GpsSignalStatus.locating);
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _updateStatus(GpsSignalStatus.denied);
        _lastError =
            'Location permission denied. Wildora requires GPS to map patrol routes.';
      } else if (permission == LocationPermission.deniedForever) {
        _updateStatus(GpsSignalStatus.permanentlyDenied);
        _lastError =
            'Location permanently denied. Please enable location in site or app settings.';
      } else {
        _updateStatus(GpsSignalStatus.available);
        _lastError = null;
      }

      return permission;
    } catch (e) {
      _updateStatus(GpsSignalStatus.providerError);
      _lastError = 'Location provider error: $e';
      return LocationPermission.denied;
    }
  }

  /// Request a single GPS fix and return a validated [TrackPoint].
  Future<TrackPoint> captureCurrentPosition() async {
    if (_isSimulationMode) {
      return _generateSimulatedPoint();
    }

    _updateStatus(GpsSignalStatus.locating);
    try {
      final position = await _readPosition();

      if (!TrackPoint.isValid(position.latitude, position.longitude)) {
        throw const FormatException('Coordinates are outside valid range.');
      }

      _lastAccuracy = position.accuracy;
      _lastFixTime = position.timestamp;
      _updateStatus(GpsSignalStatus.available);
      _lastError = null;

      return TrackPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: position.timestamp,
        accuracy: position.accuracy,
        source: LocationSource.gps,
      );
    } catch (e) {
      _handleLocationError(e);
      rethrow;
    }
  }

  /// Start continuous GPS tracking, streaming valid fixes to [onPoint].
  ///
  /// Guarantees:
  /// - Automatically validates/requests permission first.
  /// - Immediately attempts an initial fix so map centers without delay.
  /// - Sets up continuous updates with high accuracy.
  Future<void> startTracking(void Function(TrackPoint) onPoint) async {
    if (_isTracking) return;
    _isTracking = true;

    // Start stale detection timer: marks status stale if no fix received for 30s
    _startStaleTimer();

    if (_isSimulationMode) {
      _startSimulatedTracking(onPoint);
      return;
    }

    if (positionReader != null) {
      // Injected reader (e.g. tests)
      try {
        final initial = await positionReader!();
        _recordSuccessfulFix(initial, onPoint, LocationSource.gps);
      } catch (_) {}

      _trackingSubscription = Stream.periodic(
        const Duration(seconds: 3),
      ).asyncMap((_) => positionReader!()).listen(
        (position) {
          _recordSuccessfulFix(position, onPoint, LocationSource.gps);
        },
        onError: (Object e) {
          _handleLocationError(e);
        },
      );
      return;
    }

    // 1. Check and request permission
    final permission = await checkAndRequestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    // 2. Fetch immediate initial fix so ranger map has an instant location
    try {
      _updateStatus(GpsSignalStatus.locating);
      final initialPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      _recordSuccessfulFix(initialPosition, onPoint, LocationSource.gps);
    } catch (e) {
      // Non-fatal initial capture timeout; continuous stream will continue trying
      if (kDebugMode) {
        print('Initial GPS fix notice: $e');
      }
    }

    // 3. Subscribe to continuous platform location stream
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // 5 metres between fixes for field precision
    );

    _trackingSubscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(
      (position) {
        _recordSuccessfulFix(position, onPoint, LocationSource.gps);
      },
      onError: (Object e) {
        _handleLocationError(e);
      },
    );
  }

  /// Stop continuous GPS tracking and cancel timers.
  void stopTracking() {
    _isTracking = false;
    _trackingSubscription?.cancel();
    _trackingSubscription = null;
    _staleCheckTimer?.cancel();
    _staleCheckTimer = null;
    _simulationTimer?.cancel();
    _simulationTimer = null;
  }

  void dispose() {
    stopTracking();
    if (!_statusStreamController.isClosed) {
      _statusStreamController.close();
    }
  }

  // ─── Private Internal Helpers ─────────────────────────────────────

  void _recordSuccessfulFix(
    Position position,
    void Function(TrackPoint) onPoint,
    LocationSource source,
  ) {
    if (!TrackPoint.isValid(position.latitude, position.longitude)) return;

    _lastAccuracy = position.accuracy;
    _lastFixTime = position.timestamp;
    _updateStatus(GpsSignalStatus.available);
    _lastError = null;

    final point = TrackPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: position.timestamp,
      accuracy: position.accuracy,
      source: source,
    );

    onPoint(point);
  }

  Future<Position> _readPosition() async {
    if (positionReader != null) {
      return positionReader!();
    }

    await checkAndRequestPermission();

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 12),
      ),
    );
  }

  void _updateStatus(GpsSignalStatus newStatus) {
    if (_signalStatus != newStatus) {
      _signalStatus = newStatus;
      onStatusChanged?.call(newStatus);
      if (!_statusStreamController.isClosed) {
        _statusStreamController.add(newStatus);
      }
    }
  }

  void _handleLocationError(Object error) {
    final str = error.toString().toLowerCase();
    if (str.contains('denied forever') || str.contains('permanently')) {
      _updateStatus(GpsSignalStatus.permanentlyDenied);
      _lastError = 'Location permission permanently denied in browser/app.';
    } else if (str.contains('denied')) {
      _updateStatus(GpsSignalStatus.denied);
      _lastError = 'Location permission denied by user.';
    } else if (str.contains('disabled')) {
      _updateStatus(GpsSignalStatus.servicesDisabled);
      _lastError = 'Device GPS / location service is disabled.';
    } else {
      _updateStatus(GpsSignalStatus.providerError);
      _lastError = 'GPS hardware error: $error';
    }
  }

  void _startStaleTimer() {
    _staleCheckTimer?.cancel();
    _staleCheckTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_lastFixTime != null && _signalStatus == GpsSignalStatus.available) {
        final age = DateTime.now().difference(_lastFixTime!);
        if (age > const Duration(seconds: 30)) {
          _updateStatus(GpsSignalStatus.stale);
        }
      }
    });
  }

  // ─── Test Simulation Engine ───────────────────────────────────────

  static const List<List<double>> _yalaSimulatedRoute = [
    [6.3685, 81.5175],
    [6.3695, 81.5188],
    [6.3710, 81.5205],
    [6.3725, 81.5220],
    [6.3740, 81.5240],
    [6.3760, 81.5265],
    [6.3775, 81.5285],
    [6.3790, 81.5305],
    [6.3780, 81.5330],
    [6.3765, 81.5350],
  ];

  TrackPoint _generateSimulatedPoint() {
    final coord = _yalaSimulatedRoute[_simulatedStep % _yalaSimulatedRoute.length];
    _simulatedStep++;
    final now = DateTime.now();
    _lastAccuracy = 4.2;
    _lastFixTime = now;
    _updateStatus(GpsSignalStatus.available);

    return TrackPoint(
      latitude: coord[0],
      longitude: coord[1],
      timestamp: now,
      accuracy: 4.2,
      source: LocationSource.simulated,
    );
  }

  void _startSimulatedTracking(void Function(TrackPoint) onPoint) {
    _simulationTimer?.cancel();
    final initial = _generateSimulatedPoint();
    onPoint(initial);

    _simulationTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_isTracking) return;
      final point = _generateSimulatedPoint();
      onPoint(point);
    });
  }
}
