import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/high_risk_zone.dart';

/// Repository interface for HighRiskZone operations.
///
/// Provides dependency inversion for testability - domain logic depends on
/// this interface, not concrete Firestore implementation.
abstract class HighRiskZoneRepository {
  /// Get all high-risk zones
  Future<List<HighRiskZone>> getAll();

  /// Get high-risk zone by ID (optional method)
  Future<HighRiskZone?> getById(String zoneId);
}

/// Firestore implementation of HighRiskZoneRepository.
///
/// Uses cloud_firestore for persistence with highRiskZones collection.
class FirestoreHighRiskZoneRepository implements HighRiskZoneRepository {
  final FirebaseFirestore _firestore;

  FirestoreHighRiskZoneRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<HighRiskZone>> getAll() async {
    try {
      final snapshot = await _firestore
          .collection(HighRiskZone.collectionName)
          .get();

      return snapshot.docs.map((doc) {
        return HighRiskZone.fromMap(doc.id, doc.data());
      }).toList();
    } catch (e) {
      throw Exception('Failed to get all high-risk zones: $e');
    }
  }

  @override
  Future<HighRiskZone?> getById(String zoneId) async {
    try {
      final doc = await _firestore
          .collection(HighRiskZone.collectionName)
          .doc(zoneId)
          .get();

      if (!doc.exists || doc.data() == null) {
        return null;
      }

      return HighRiskZone.fromMap(doc.id, doc.data()!);
    } catch (e) {
      throw Exception('Failed to get high-risk zone $zoneId: $e');
    }
  }
}
