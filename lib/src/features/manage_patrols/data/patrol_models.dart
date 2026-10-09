import 'dart:math';

// ─── Enums ──────────────────────────────────────────────────────────

/// Lifecycle state of a patrol session.
enum PatrolLifecycleStatus { assigned, active, completed }

/// How a location was obtained.
enum LocationSource { gps, manual }

/// Category of waypoint recorded in the field.
enum WaypointType {
  animalSighting,
  evidence,
  trailMarker,
  waterSource,
  other;

  String get label {
    switch (this) {
      case WaypointType.animalSighting:
        return 'Animal Sighting';
      case WaypointType.evidence:
        return 'Evidence';
      case WaypointType.trailMarker:
        return 'Trail Marker';
      case WaypointType.waterSource:
        return 'Water Source';
      case WaypointType.other:
        return 'Other';
    }
  }
}

/// Remote synchronization status for a patrol session.
enum SyncStatus { pendingSync, synchronized, syncFailed }

// ─── ID Generation ──────────────────────────────────────────────────

/// Generate a unique 32-hex-char session ID.
String newPatrolSessionId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

/// Generate a unique 16-hex-char waypoint ID.
String newWaypointId() {
  final random = Random.secure();
  return List.generate(
    8,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

// ─── TrackPoint ─────────────────────────────────────────────────────

/// A GPS-recorded position along the patrol track.
class TrackPoint {
  const TrackPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.accuracy,
    this.source = LocationSource.gps,
  });

  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double accuracy;
  final LocationSource source;

  Map<String, dynamic> toMap() => {
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'accuracy': accuracy,
        'source': source.name,
      };

  factory TrackPoint.fromMap(Map<dynamic, dynamic> map) => TrackPoint(
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        timestamp: DateTime.parse(map['timestamp'] as String).toLocal(),
        accuracy: (map['accuracy'] as num).toDouble(),
        source: LocationSource.values.byName(map['source'] as String),
      );

  /// Validates that coordinates are finite and within valid ranges.
  static bool isValid(double lat, double lng) =>
      lat.isFinite &&
      lng.isFinite &&
      lat >= -90 &&
      lat <= 90 &&
      lng >= -180 &&
      lng <= 180;
}

// ─── Waypoint ───────────────────────────────────────────────────────

/// A point of interest recorded by the ranger during a patrol.
class Waypoint {
  const Waypoint({
    required this.id,
    required this.sessionId,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.locationSource,
    required this.timestamp,
    this.note,
    this.photoReference,
  });

  final String id;
  final String sessionId;
  final WaypointType type;
  final double latitude;
  final double longitude;
  final LocationSource locationSource;
  final DateTime timestamp;
  final String? note;
  final String? photoReference;

  Map<String, dynamic> toMap() => {
        'id': id,
        'sessionId': sessionId,
        'type': type.name,
        'latitude': latitude,
        'longitude': longitude,
        'locationSource': locationSource.name,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'note': note,
        'photoReference': photoReference,
      };

  factory Waypoint.fromMap(Map<dynamic, dynamic> map) => Waypoint(
        id: map['id'] as String,
        sessionId: map['sessionId'] as String,
        type: WaypointType.values.byName(map['type'] as String),
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        locationSource:
            LocationSource.values.byName(map['locationSource'] as String),
        timestamp: DateTime.parse(map['timestamp'] as String).toLocal(),
        note: map['note'] as String?,
        photoReference: map['photoReference'] as String?,
      );
}

// ─── SyncMetadata ───────────────────────────────────────────────────

/// Tracks the synchronization state between local storage and remote server.
class SyncMetadata {
  const SyncMetadata({
    this.syncStatus = SyncStatus.pendingSync,
    this.localRevision = 1,
    this.serverRevision,
    this.lastSyncError,
  });

  final SyncStatus syncStatus;
  final int localRevision;
  final int? serverRevision;
  final String? lastSyncError;

  SyncMetadata copyWith({
    SyncStatus? syncStatus,
    int? localRevision,
    int? serverRevision,
    String? lastSyncError,
  }) =>
      SyncMetadata(
        syncStatus: syncStatus ?? this.syncStatus,
        localRevision: localRevision ?? this.localRevision,
        serverRevision: serverRevision ?? this.serverRevision,
        lastSyncError: lastSyncError,
      );

  Map<String, dynamic> toMap() => {
        'syncStatus': syncStatus.name,
        'localRevision': localRevision,
        'serverRevision': serverRevision,
        'lastSyncError': lastSyncError,
      };

  factory SyncMetadata.fromMap(Map<dynamic, dynamic> map) => SyncMetadata(
        syncStatus: SyncStatus.values.byName(map['syncStatus'] as String),
        localRevision: (map['localRevision'] as num).toInt(),
        serverRevision: (map['serverRevision'] as num?)?.toInt(),
        lastSyncError: map['lastSyncError'] as String?,
      );
}

// ─── RouteDeviation ─────────────────────────────────────────────────

/// Records when a ranger deviated from the assigned route.
class RouteDeviation {
  const RouteDeviation({
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.reason,
  });

  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final String? reason;

  Map<String, dynamic> toMap() => {
        'timestamp': timestamp.toUtc().toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'reason': reason,
      };

  factory RouteDeviation.fromMap(Map<dynamic, dynamic> map) => RouteDeviation(
        timestamp: DateTime.parse(map['timestamp'] as String).toLocal(),
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        reason: map['reason'] as String?,
      );
}

// ─── PatrolSession ──────────────────────────────────────────────────

/// Full patrol session encompassing assignment, tracking, and completion data.
class PatrolSession {
  const PatrolSession({
    required this.sessionId,
    required this.assignedRouteId,
    this.rangerId,
    this.startTime,
    this.endTime,
    this.lifecycleStatus = PatrolLifecycleStatus.assigned,
    this.revision = 1,
    this.routeName = 'Assigned Patrol Route',
    this.estimatedDurationMinutes = 120,
    this.plannedDistanceKm = 8.5,
    this.deviations = const [],
    this.trackPoints = const [],
    this.waypoints = const [],
    this.syncMetadata = const SyncMetadata(),
  });

  final String sessionId;
  final String assignedRouteId;
  final String? rangerId;
  final DateTime? startTime;
  final DateTime? endTime;
  final PatrolLifecycleStatus lifecycleStatus;
  final int revision;
  final String routeName;
  final int estimatedDurationMinutes;
  final double plannedDistanceKm;
  final List<RouteDeviation> deviations;
  final List<TrackPoint> trackPoints;
  final List<Waypoint> waypoints;
  final SyncMetadata syncMetadata;

  /// Actual elapsed duration. Uses endTime for completed patrols.
  Duration get actualDuration {
    if (startTime == null) return Duration.zero;
    final end = endTime ?? DateTime.now();
    return end.difference(startTime!);
  }

  /// Recorded GPS travel distance in kilometres (excludes manual waypoints).
  double get recordedDistanceKm {
    if (trackPoints.length < 2) return 0.0;
    double total = 0.0;
    for (int i = 1; i < trackPoints.length; i++) {
      total += _haversineKm(
        trackPoints[i - 1].latitude,
        trackPoints[i - 1].longitude,
        trackPoints[i].latitude,
        trackPoints[i].longitude,
      );
    }
    return total;
  }

  /// Whether there were gaps in GPS recording.
  bool get hasGpsGaps {
    if (trackPoints.length < 2) return lifecycleStatus == PatrolLifecycleStatus.completed;
    for (int i = 1; i < trackPoints.length; i++) {
      final gap =
          trackPoints[i].timestamp.difference(trackPoints[i - 1].timestamp);
      if (gap.inMinutes > 5) return true;
    }
    return false;
  }

  PatrolSession copyWith({
    String? sessionId,
    String? assignedRouteId,
    String? rangerId,
    DateTime? startTime,
    DateTime? endTime,
    PatrolLifecycleStatus? lifecycleStatus,
    int? revision,
    String? routeName,
    int? estimatedDurationMinutes,
    double? plannedDistanceKm,
    List<RouteDeviation>? deviations,
    List<TrackPoint>? trackPoints,
    List<Waypoint>? waypoints,
    SyncMetadata? syncMetadata,
  }) =>
      PatrolSession(
        sessionId: sessionId ?? this.sessionId,
        assignedRouteId: assignedRouteId ?? this.assignedRouteId,
        rangerId: rangerId ?? this.rangerId,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        lifecycleStatus: lifecycleStatus ?? this.lifecycleStatus,
        revision: revision ?? this.revision,
        routeName: routeName ?? this.routeName,
        estimatedDurationMinutes:
            estimatedDurationMinutes ?? this.estimatedDurationMinutes,
        plannedDistanceKm: plannedDistanceKm ?? this.plannedDistanceKm,
        deviations: deviations ?? this.deviations,
        trackPoints: trackPoints ?? this.trackPoints,
        waypoints: waypoints ?? this.waypoints,
        syncMetadata: syncMetadata ?? this.syncMetadata,
      );

  Map<String, dynamic> toMap() => {
        'sessionId': sessionId,
        'assignedRouteId': assignedRouteId,
        'rangerId': rangerId,
        'startTime': startTime?.toUtc().toIso8601String(),
        'endTime': endTime?.toUtc().toIso8601String(),
        'lifecycleStatus': lifecycleStatus.name,
        'revision': revision,
        'routeName': routeName,
        'estimatedDurationMinutes': estimatedDurationMinutes,
        'plannedDistanceKm': plannedDistanceKm,
        'deviations': deviations.map((d) => d.toMap()).toList(),
        'trackPoints': trackPoints.map((t) => t.toMap()).toList(),
        'waypoints': waypoints.map((w) => w.toMap()).toList(),
        'syncMetadata': syncMetadata.toMap(),
      };

  factory PatrolSession.fromMap(Map<dynamic, dynamic> map) => PatrolSession(
        sessionId: map['sessionId'] as String,
        assignedRouteId: map['assignedRouteId'] as String,
        rangerId: map['rangerId'] as String?,
        startTime: map['startTime'] != null
            ? DateTime.parse(map['startTime'] as String).toLocal()
            : null,
        endTime: map['endTime'] != null
            ? DateTime.parse(map['endTime'] as String).toLocal()
            : null,
        lifecycleStatus: PatrolLifecycleStatus.values
            .byName(map['lifecycleStatus'] as String),
        revision: (map['revision'] as num).toInt(),
        routeName: map['routeName'] as String? ?? 'Assigned Patrol Route',
        estimatedDurationMinutes:
            (map['estimatedDurationMinutes'] as num?)?.toInt() ?? 120,
        plannedDistanceKm:
            (map['plannedDistanceKm'] as num?)?.toDouble() ?? 8.5,
        deviations: (map['deviations'] as List? ?? [])
            .map((d) => RouteDeviation.fromMap(d as Map))
            .toList(),
        trackPoints: (map['trackPoints'] as List? ?? [])
            .map((t) => TrackPoint.fromMap(t as Map))
            .toList(),
        waypoints: (map['waypoints'] as List? ?? [])
            .map((w) => Waypoint.fromMap(w as Map))
            .toList(),
        syncMetadata: map['syncMetadata'] != null
            ? SyncMetadata.fromMap(map['syncMetadata'] as Map)
            : const SyncMetadata(),
      );

  /// Haversine formula to calculate distance between two GPS coordinates in km.
  static double _haversineKm(
      double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degreesToRadians(double degrees) => degrees * pi / 180;
}
