/// Detection system configuration with locked defaults.
///
/// These are the configurable defaults that control proximity-based
/// alert routing and location freshness validation. Values are locked
/// for Assignment 02 implementation but designed to be configurable
/// in future versions.
class DetectionConfig {
  /// Proximity radius in meters for determining which officers receive alerts.
  /// Officers within this radius of a zone center will receive notifications.
  ///
  /// LOCKED DEFAULT: 5000.0 meters (5km) - reasonable for wildlife park coverage.
  static const double notifyRadiusMeters = 5000.0;

  /// Maximum age in minutes for ranger location data to be considered fresh.
  /// Rangers with stale locations are excluded from proximity-based routing.
  ///
  /// LOCKED DEFAULT: 30 minutes - balances patrol mobility with reliability.
  static const int maxLocationAgeMinutes = 30;

  /// Fallback count for nearest officers when no nearby officers are found.
  /// Used to prevent alerts from being lost in remote areas.
  ///
  /// OPTIONAL DEFAULT: 2 officers - provides emergency coverage redundancy.
  static const int nearestFallbackCount = 2;

  /// Private constructor - this is a constants-only class
  const DetectionConfig._();
}
