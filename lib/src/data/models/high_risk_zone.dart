import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model for HighRiskZone collection.
///
/// Schema/data model justified by the Wildora class diagram and
/// Detect High-Risk Animal Movement scenario. Persistence/repository
/// logic is NOT part of this foundation.
class HighRiskZone {
  static const String collectionName = 'highRiskZones';

  final String zoneId;
  final String name;
  final String riskLevel;
  final GeoPoint center;
  final double radiusMeters;

  const HighRiskZone({
    required this.zoneId,
    required this.name,
    required this.riskLevel,
    required this.center,
    required this.radiusMeters,
  });

  factory HighRiskZone.fromMap(String id, Map<String, dynamic> map) {
    return HighRiskZone(
      zoneId: id,
      name: map['name'] as String,
      riskLevel: map['riskLevel'] as String,
      center: map['center'] as GeoPoint,
      radiusMeters: (map['radiusMeters'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'zoneId': zoneId,
      'name': name,
      'riskLevel': riskLevel,
      'center': center,
      'radiusMeters': radiusMeters,
    };
  }
}
