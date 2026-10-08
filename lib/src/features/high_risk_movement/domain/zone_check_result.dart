/// Immutable result of a zone detection check.
///
/// Contains all the information needed to determine if an alert should be
/// generated and provides context for logging and debugging.
class ZoneCheckResult {
  /// Whether the checked location is inside any high-risk zone.
  final bool inZone;

  /// The ID of the matched zone, if any.
  /// Null if no zone was matched.
  final String? matchedZoneId;

  /// Distance in meters to the matched zone center.
  /// Null if no zone was matched.
  /// For matched zones, this will be <= the zone's radius.
  final double? distanceMeters;

  const ZoneCheckResult({
    required this.inZone,
    this.matchedZoneId,
    this.distanceMeters,
  });

  /// Creates a result indicating no zone was matched.
  const ZoneCheckResult.notInZone()
    : inZone = false,
      matchedZoneId = null,
      distanceMeters = null;

  /// Creates a result indicating a zone was matched.
  const ZoneCheckResult.inZone({
    required String zoneId,
    required double distance,
  }) : inZone = true,
       matchedZoneId = zoneId,
       distanceMeters = distance;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZoneCheckResult &&
          runtimeType == other.runtimeType &&
          inZone == other.inZone &&
          matchedZoneId == other.matchedZoneId &&
          distanceMeters == other.distanceMeters;

  @override
  int get hashCode =>
      inZone.hashCode ^ matchedZoneId.hashCode ^ distanceMeters.hashCode;

  @override
  String toString() {
    if (!inZone) {
      return 'ZoneCheckResult.notInZone()';
    }
    return 'ZoneCheckResult.inZone(zoneId: $matchedZoneId, distance: ${distanceMeters?.toStringAsFixed(1)}m)';
  }
}
