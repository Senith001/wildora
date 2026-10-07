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
  final String animalId;
  final String zoneId;
  final AlertLocation location;
  final String animalName;

  const Alert({
    required this.alertId,
    required this.type,
    required this.timestamp,
    required this.status,
    required this.animalId,
    required this.zoneId,
    required this.location,
    required this.animalName,
  });

  factory Alert.fromMap(String id, Map<String, dynamic> map) {
    return Alert(
      alertId: id,
      type: map['type'] as String,
      timestamp: map['timestamp'] as Timestamp,
      status: map['status'] as String,
      animalId: map['animalId'] as String,
      zoneId: map['zoneId'] as String,
      location: AlertLocation.fromMap(map['location'] as Map<String, dynamic>),
      animalName: map['animalName'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'alertId': alertId,
      'type': type,
      'timestamp': timestamp,
      'status': status,
      'animalId': animalId,
      'zoneId': zoneId,
      'location': location.toMap(),
      'animalName': animalName,
    };
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
