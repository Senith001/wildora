import 'dart:math' as math;

/// A 2D geographic point with latitude and longitude coordinates.
///
/// This is a pure value class for geospatial calculations without
/// any Flutter or Firebase dependencies.
class GeoPoint2D {
  final double latitude;
  final double longitude;

  const GeoPoint2D({required this.latitude, required this.longitude});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeoPoint2D &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;

  @override
  String toString() => 'GeoPoint2D($latitude, $longitude)';
}

/// Calculates the distance between two geographic points using the Haversine formula.
///
/// Returns the great circle distance in meters between the two points.
/// Accurate for distances up to a few hundred kilometers.
///
/// Parameters:
/// - [lat1], [lon1]: First point coordinates in decimal degrees
/// - [lat2], [lon2]: Second point coordinates in decimal degrees
///
/// Returns distance in meters.
double haversineMeters(double lat1, double lon1, double lat2, double lon2) {
  const double earthRadiusMeters = 6371000; // Earth's radius in meters

  // Convert latitude and longitude from degrees to radians
  final double lat1Rad = lat1 * math.pi / 180;
  final double lat2Rad = lat2 * math.pi / 180;
  final double deltaLatRad = (lat2 - lat1) * math.pi / 180;
  final double deltaLonRad = (lon2 - lon1) * math.pi / 180;

  // Haversine formula
  final double a =
      math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
      math.cos(lat1Rad) *
          math.cos(lat2Rad) *
          math.sin(deltaLonRad / 2) *
          math.sin(deltaLonRad / 2);

  final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

  return earthRadiusMeters * c;
}

/// Checks if a point is within a circular radius from a center point.
///
/// This is a convenience helper for point-in-circle geofencing tests.
/// Uses haversine distance calculation for accuracy.
///
/// Parameters:
/// - [point]: The point to test
/// - [center]: The center of the circle
/// - [radiusMeters]: The radius in meters (inclusive boundary)
///
/// Returns true if the point is within or exactly on the radius boundary.
bool isWithinRadius(GeoPoint2D point, GeoPoint2D center, double radiusMeters) {
  final double distance = haversineMeters(
    point.latitude,
    point.longitude,
    center.latitude,
    center.longitude,
  );

  return distance <= radiusMeters; // Inclusive boundary
}
