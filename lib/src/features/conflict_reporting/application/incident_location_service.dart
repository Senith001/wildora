import 'dart:async';

import 'package:geolocator/geolocator.dart';

class IncidentLocation {
  const IncidentLocation(this.latitude, this.longitude, {this.accuracy});
  final double latitude;
  final double longitude;
  final double? accuracy;
}

class LocationUnavailable implements Exception {
  const LocationUnavailable(this.message);
  final String message;
}

abstract interface class IncidentLocationService {
  Future<IncidentLocation> currentLocation();
}

/// Permission decisions and GPS timeout live outside the widget. Unavailable
/// GPS produces an explicit recovery message instead of invented coordinates.
class DeviceIncidentLocationService implements IncidentLocationService {
  DeviceIncidentLocationService({GeolocatorPlatform? platform})
    : _platform = platform ?? GeolocatorPlatform.instance;
  final GeolocatorPlatform _platform;

  @override
  Future<IncidentLocation> currentLocation() async {
    if (!await _platform.isLocationServiceEnabled()) {
      throw const LocationUnavailable(
        'Enable location services or enter the incident coordinates manually.',
      );
    }
    var permission = await _platform.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _platform.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationUnavailable(
        'Location permission is blocked. Enable it in app settings or enter coordinates.',
      );
    }
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      throw const LocationUnavailable(
        'Location permission is needed. Try again or enter coordinates manually.',
      );
    }
    try {
      final position = await _platform.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return IncidentLocation(
        position.latitude,
        position.longitude,
        accuracy: position.accuracy,
      );
    } on TimeoutException {
      throw const LocationUnavailable(
        'GPS timed out. Try again outdoors or enter coordinates manually.',
      );
    }
  }
}
