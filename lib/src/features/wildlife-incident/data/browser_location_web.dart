import 'dart:async';
import 'dart:js_interop';
import 'package:geolocator/geolocator.dart';
import 'package:web/web.dart' as browser;

/// Keep browser options as JS-compatible numbers, never Dart Duration objects.
Future<Position> browserPosition({
  required bool highAccuracy,
  required Duration timeLimit,
}) {
  final result = Completer<Position>();
  try {
    browser.window.navigator.geolocation.getCurrentPosition(
      ((browser.GeolocationPosition position) {
        if (result.isCompleted) return;
        final coordinates = position.coords;
        result.complete(
          Position(
            latitude: coordinates.latitude,
            longitude: coordinates.longitude,
            timestamp: DateTime.fromMillisecondsSinceEpoch(position.timestamp),
            accuracy: coordinates.accuracy,
            altitude: coordinates.altitude ?? 0,
            altitudeAccuracy: coordinates.altitudeAccuracy ?? 0,
            heading: coordinates.heading ?? 0,
            headingAccuracy: 0,
            speed: coordinates.speed ?? 0,
            speedAccuracy: 0,
          ),
        );
      }).toJS,
      ((browser.GeolocationPositionError error) {
        if (result.isCompleted) return;
        final Exception failure = switch (error.code) {
          1 => PermissionDeniedException(error.message),
          3 => TimeoutException(error.message, timeLimit),
          _ => PositionUpdateException(error.message),
        };
        result.completeError(failure);
      }).toJS,
      browser.PositionOptions(
        enableHighAccuracy: highAccuracy,
        timeout: timeLimit.inMilliseconds,
        maximumAge: 0,
      ),
    );
  } catch (error, stack) {
    result.completeError(error, stack);
  }
  return result.future.timeout(timeLimit);
}
