import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'location_environment.dart';
import 'browser_location.dart';

class IncidentLocationService {
  IncidentLocationService({
    this.web = kIsWeb,
    this.secureContext,
    this.positionReader,
  });
  final bool web;
  final bool? secureContext;
  final Future<Position> Function(LocationSettings settings)? positionReader;

  Future<Position> capture() async {
    if (web) {
      if (!(secureContext ?? locationContextIsSecure)) {
        throw StateError(
          'Browser location requires HTTPS or localhost. Open this app at localhost instead of an HTTP network/IP address.',
        );
      }
      // Call geolocation directly: it prompts for permission even in browsers
      // that do not expose a working Permissions API.
      try {
        return await _read(
          WebSettings(
            accuracy: LocationAccuracy.high,
            maximumAge: Duration.zero,
            timeLimit: const Duration(seconds: 35),
          ),
        );
      } on TimeoutException {
        // Desktop browsers may lack GPS. A fresh balanced-accuracy network fix
        // is still a device-provided location, with its actual accuracy shown.
        return _read(
          WebSettings(
            accuracy: LocationAccuracy.medium,
            maximumAge: Duration.zero,
            timeLimit: const Duration(seconds: 15),
          ),
        );
      } on PositionUpdateException {
        return _read(
          WebSettings(
            accuracy: LocationAccuracy.medium,
            maximumAge: Duration.zero,
            timeLimit: const Duration(seconds: 15),
          ),
        );
      }
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
    return _read(
      const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 35),
      ),
    );
  }

  Future<Position> _read(LocationSettings settings) {
    final read =
        positionReader?.call(settings) ??
        (web
            ? browserPosition(
                highAccuracy: settings.accuracy == LocationAccuracy.high,
                timeLimit: settings.timeLimit!,
              )
            : Geolocator.getCurrentPosition(locationSettings: settings));
    return read.timeout(settings.timeLimit!);
  }
}

String locationFailureMessage(Object error, {bool web = kIsWeb}) {
  if (error is PermissionDeniedException) {
    return web
        ? 'Location access is blocked. In your browser’s site settings, allow Location for this site and reload. Also allow the browser in your computer’s location settings. If using an embedded preview, open the app in its own tab.'
        : 'Allow this app to access location in your device settings, then retry.';
  }
  if (error is TimeoutException || error is PositionUpdateException) {
    return web
        ? 'Your browser could not determine your location. Enable location services for your browser in your computer’s settings, check your connection, then retry or enter coordinates manually.'
        : 'No location fix was received. Turn on location services and retry outdoors, or enter coordinates manually.';
  }
  if (error is LocationServiceDisabledException) {
    return 'Turn on device location services, then retry.';
  }
  return 'Unable to capture location: $error';
}
