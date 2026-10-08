import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/config/detection_config.dart';
import '../../../data/models/high_risk_zone.dart';
import '../../../data/repositories/officer_repository.dart';
import '../../../data/repositories/duty_roster_repository.dart';
import '../../../data/repositories/high_risk_zone_repository.dart';
import '../domain/geo.dart';
import '../domain/zone_check_result.dart';

/// Pure-ish service for high-risk zone detection and officer proximity resolution.
///
/// This service implements the core business logic for:
/// 1. Point-in-circle zone detection with tie-breaking rules
/// 2. Proximity-based recipient resolution with role/duty/freshness filters
/// 3. Nearest-2 fallback when no nearby officers are found
///
/// Depends only on repository interfaces (DIP) for testability with fakes.
class HighRiskZoneDetectionService {
  final OfficerRepository _officerRepository;
  final DutyRosterRepository _dutyRosterRepository;
  final HighRiskZoneRepository _zoneRepository;

  HighRiskZoneDetectionService({
    required OfficerRepository officerRepository,
    required DutyRosterRepository dutyRosterRepository,
    required HighRiskZoneRepository zoneRepository,
  }) : _officerRepository = officerRepository,
       _dutyRosterRepository = dutyRosterRepository,
       _zoneRepository = zoneRepository;

  /// Check if location is within any high-risk zones.
  ///
  /// Implements point-in-circle detection over all zones with tie-breaking:
  /// - Multiple matches: prefer smallest distance first, then highest risk level
  /// - Single match or no match: return accordingly
  ///
  /// Returns [ZoneCheckResult] with match details and distance.
  Future<ZoneCheckResult> checkZones(GeoPoint2D location) async {
    final zones = await _zoneRepository.getAll();

    if (zones.isEmpty) {
      return ZoneCheckResult.notInZone();
    }

    final List<_ZoneMatch> matches = [];

    // Check all zones for point-in-circle matches
    for (final zone in zones) {
      final zoneCenter = GeoPoint2D(
        latitude: zone.center.latitude,
        longitude: zone.center.longitude,
      );

      final distance = haversineMeters(
        location.latitude,
        location.longitude,
        zoneCenter.latitude,
        zoneCenter.longitude,
      );

      // Inclusive boundary check (distance <= radius)
      if (distance <= zone.radiusMeters) {
        matches.add(_ZoneMatch(zone: zone, distance: distance));
      }
    }

    if (matches.isEmpty) {
      return ZoneCheckResult.notInZone();
    }

    if (matches.length == 1) {
      final match = matches.first;
      return ZoneCheckResult.inZone(
        zoneId: match.zone.zoneId,
        distance: match.distance,
      );
    }

    // Multiple zone matches - apply tie-breaking rules
    // 1. Smallest distance first
    // 2. If distances are equal, highest risk level
    matches.sort((a, b) {
      final distanceComparison = a.distance.compareTo(b.distance);
      if (distanceComparison != 0) {
        return distanceComparison;
      }

      // Compare risk levels: High > Medium > Low
      return _riskLevelPriority(b.zone.riskLevel)
          .compareTo(_riskLevelPriority(a.zone.riskLevel));
    });

    final winningMatch = matches.first;
    return ZoneCheckResult.inZone(
      zoneId: winningMatch.zone.zoneId,
      distance: winningMatch.distance,
    );
  }

  /// Resolve nearby recipients for an alert at the given zone center.
  ///
  /// Implements EXACTLY the locked proximity rules:
  /// - Rangers: on-duty + fresh location (≤ 30min) + within 5km
  /// - CLOs: within 5km (no duty/freshness check)
  /// - Fallback: nearest-2 among role-eligible when no nearby officers
  ///
  /// Returns list of officer IDs (or Officer objects - caller's choice).
  Future<List<String>> resolveNearbyRecipients(
    GeoPoint zoneCenter,
    DateTime now,
  ) async {
    final zoneLocation = GeoPoint2D(
      latitude: zoneCenter.latitude,
      longitude: zoneCenter.longitude,
    );

    // Get today's date string for duty roster lookup
    final todayString = _formatDateForDutyRoster(now);

    // Fetch all required data
    final officers = await _officerRepository.getAll();
    final dutyRoster = await _dutyRosterRepository.getByDate(todayString);
    final onDutyRangerIds = dutyRoster?.onDutyRangerIds.toSet() ?? <String>{};

    final List<String> nearbyRecipients = [];
    final List<_OfficerDistance> allEligibleOfficers = [];

    for (final officer in officers) {
      if (officer.location == null) {
        continue; // Skip officers without location
      }

      final officerLocation = GeoPoint2D(
        latitude: officer.location!.latitude,
        longitude: officer.location!.longitude,
      );

      final distance = haversineMeters(
        zoneLocation.latitude,
        zoneLocation.longitude,
        officerLocation.latitude,
        officerLocation.longitude,
      );

      // Track all eligible officers for potential fallback
      final isRanger = officer.role == 'ranger';
      final isClo = officer.role == 'clo';

      if (isRanger && onDutyRangerIds.contains(officer.officerId)) {
        // Ranger eligible for fallback only if they also have fresh location
        if (_isLocationFresh(officer.locationUpdatedAt, now)) {
          allEligibleOfficers.add(
            _OfficerDistance(officer.officerId, distance),
          );
        }
      } else if (isClo) {
        // CLO eligible for both nearby and fallback
        allEligibleOfficers.add(_OfficerDistance(officer.officerId, distance));
      }

      // Check proximity for nearby selection (≤ 5000m)
      if (distance <= DetectionConfig.notifyRadiusMeters) {
        if (isRanger) {
          // Ranger must be on-duty AND have fresh location
          if (onDutyRangerIds.contains(officer.officerId) &&
              _isLocationFresh(officer.locationUpdatedAt, now)) {
            nearbyRecipients.add(officer.officerId);
          }
        } else if (isClo) {
          // CLO only needs to be nearby (no duty/freshness check)
          nearbyRecipients.add(officer.officerId);
        }
      }
    }

    // If we have nearby recipients, return them
    if (nearbyRecipients.isNotEmpty) {
      return nearbyRecipients;
    }

    // No nearby officers - apply nearest-2 fallback
    if (allEligibleOfficers.isEmpty) {
      return []; // No eligible officers at all
    }

    // Sort by distance and take up to 2 nearest
    allEligibleOfficers.sort((a, b) => a.distance.compareTo(b.distance));
    final fallbackCount =
        allEligibleOfficers.length < DetectionConfig.nearestFallbackCount
        ? allEligibleOfficers.length
        : DetectionConfig.nearestFallbackCount;

    return allEligibleOfficers
        .take(fallbackCount)
        .map((od) => od.officerId)
        .toList();
  }

  /// Check if officer location is fresh (within maxLocationAgeMinutes).
  bool _isLocationFresh(Timestamp? locationUpdatedAt, DateTime now) {
    if (locationUpdatedAt == null) {
      return false; // No timestamp = stale
    }

    final locationTime = locationUpdatedAt.toDate();
    final maxAge = Duration(minutes: DetectionConfig.maxLocationAgeMinutes);

    return now.difference(locationTime) <= maxAge;
  }

  /// Format DateTime to yyyy-MM-dd string for duty roster lookup.
  String _formatDateForDutyRoster(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  /// Get numeric priority for risk level tie-breaking.
  /// Higher numbers = higher priority.
  int _riskLevelPriority(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'high':
        return 3;
      case 'medium':
        return 2;
      case 'low':
        return 1;
      default:
        return 0;
    }
  }
}

/// Internal helper class for zone matching with distance.
class _ZoneMatch {
  final HighRiskZone zone;
  final double distance;

  _ZoneMatch({required this.zone, required this.distance});
}

/// Internal helper class for officer distance tracking.
class _OfficerDistance {
  final String officerId;
  final double distance;

  _OfficerDistance(this.officerId, this.distance);
}
