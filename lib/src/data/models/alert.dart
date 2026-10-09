import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model for Alert collection.
///
/// Schema/data model justified by the Wildora class diagram and
/// Detect High-Risk Animal Movement scenario. Persistence/repository
/// logic is NOT part of this foundation.
class Alert {
  static const String collectionName = 'alerts';

  final String alertId;
  final String type;
  final Timestamp timestamp;
  final String status;
  final String responseStatus; // 'unclaimed' | 'responding' | 'resolved'
  final String? respondingOfficerId;
  final String? respondingOfficerName;
  final Timestamp? respondingAt;
  final String animalId;
  final String zoneId;
  final AlertLocation location;
  final String animalName;
  final String? locationLabel;

  const Alert({
    required this.alertId,
    required this.type,
    required this.timestamp,
    required this.status,
    required this.responseStatus,
    this.respondingOfficerId,
    this.respondingOfficerName,
    this.respondingAt,
    required this.animalId,
    required this.zoneId,
    required this.location,
    required this.animalName,
    this.locationLabel,
  });

  factory Alert.fromMap(String id, Map<String, dynamic> map) {
    return Alert(
      alertId: id,
      type: map['type'] as String,
      timestamp: map['timestamp'] as Timestamp,
      status: map['status'] as String,
      responseStatus: map['responseStatus'] as String? ?? 'unclaimed',
      respondingOfficerId: map['respondingOfficerId'] as String?,
      respondingOfficerName: map['respondingOfficerName'] as String?,
      respondingAt: map['respondingAt'] as Timestamp?,
      animalId: map['animalId'] as String,
      zoneId: map['zoneId'] as String,
      location: AlertLocation.fromMap(map['location'] as Map<String, dynamic>),
      animalName: map['animalName'] as String,
      locationLabel: map['locationLabel'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'alertId': alertId,
      'type': type,
      'timestamp': timestamp,
      'status': status,
      'responseStatus': responseStatus,
      'respondingOfficerId': respondingOfficerId,
      'respondingOfficerName': respondingOfficerName,
      'respondingAt': respondingAt,
      'animalId': animalId,
      'zoneId': zoneId,
      'location': location.toMap(),
      'animalName': animalName,
      'locationLabel': locationLabel,
    };
  }

  /// Create a copy with updated fields
  Alert copyWith({
    String? alertId,
    String? type,
    Timestamp? timestamp,
    String? status,
    String? responseStatus,
    String? respondingOfficerId,
    String? respondingOfficerName,
    Timestamp? respondingAt,
    String? animalId,
    String? zoneId,
    AlertLocation? location,
    String? animalName,
    String? locationLabel,
  }) {
    return Alert(
      alertId: alertId ?? this.alertId,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      responseStatus: responseStatus ?? this.responseStatus,
      respondingOfficerId: respondingOfficerId ?? this.respondingOfficerId,
      respondingOfficerName:
          respondingOfficerName ?? this.respondingOfficerName,
      respondingAt: respondingAt ?? this.respondingAt,
      animalId: animalId ?? this.animalId,
      zoneId: zoneId ?? this.zoneId,
      location: location ?? this.location,
      animalName: animalName ?? this.animalName,
      locationLabel: locationLabel ?? this.locationLabel,
    );
  }
}

/// Value class for alert location data.
class AlertLocation {
  final double latitude;
  final double longitude;

  const AlertLocation({required this.latitude, required this.longitude});

  factory AlertLocation.fromMap(Map<String, dynamic> map) {
    return AlertLocation(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'latitude': latitude, 'longitude': longitude};
  }
}

/// Constants for alert response status values.
class AlertResponseStatus {
  static const String unclaimed = 'unclaimed';
  static const String responding = 'responding';
  static const String resolved = 'resolved';

  const AlertResponseStatus._();
}
