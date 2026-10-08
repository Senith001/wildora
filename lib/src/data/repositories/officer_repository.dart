import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/officer.dart';

/// Repository interface for Officer operations.
///
/// Provides dependency inversion for testability - domain logic depends on
/// this interface, not concrete Firestore implementation.
abstract class OfficerRepository {
  /// Get all officers
  Future<List<Officer>> getAll();

  /// Get officers by role ('ranger' or 'clo')
  Future<List<Officer>> getByRole(String role);

  /// Add FCM token to officer's token list
  Future<void> addFcmToken(String officerId, String token);

  /// Remove FCM token from officer's token list
  Future<void> removeFcmToken(String officerId, String token);

  /// Update officer's location
  Future<void> updateLocation(
    String officerId,
    GeoPoint location,
    Timestamp timestamp,
  );
}

/// Firestore implementation of OfficerRepository.
///
/// Uses cloud_firestore for persistence with officers collection.
/// Manages FCM token arrays and location updates for proximity filtering.
class FirestoreOfficerRepository implements OfficerRepository {
  final FirebaseFirestore _firestore;

  FirestoreOfficerRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<Officer>> getAll() async {
    try {
      final snapshot = await _firestore
          .collection(Officer.collectionName)
          .get();

      return snapshot.docs.map((doc) {
        return Officer.fromMap(doc.id, doc.data());
      }).toList();
    } catch (e) {
      throw Exception('Failed to get all officers: $e');
    }
  }

  @override
  Future<List<Officer>> getByRole(String role) async {
    try {
      final snapshot = await _firestore
          .collection(Officer.collectionName)
          .where('role', isEqualTo: role)
          .get();

      return snapshot.docs.map((doc) {
        return Officer.fromMap(doc.id, doc.data());
      }).toList();
    } catch (e) {
      throw Exception('Failed to get officers by role $role: $e');
    }
  }

  @override
  Future<void> addFcmToken(String officerId, String token) async {
    try {
      await _firestore.collection(Officer.collectionName).doc(officerId).update(
        {
          'fcmTokens': FieldValue.arrayUnion([token]),
        },
      );
    } catch (e) {
      throw Exception('Failed to add FCM token for officer $officerId: $e');
    }
  }

  @override
  Future<void> removeFcmToken(String officerId, String token) async {
    try {
      await _firestore.collection(Officer.collectionName).doc(officerId).update(
        {
          'fcmTokens': FieldValue.arrayRemove([token]),
        },
      );
    } catch (e) {
      throw Exception('Failed to remove FCM token for officer $officerId: $e');
    }
  }

  @override
  Future<void> updateLocation(
    String officerId,
    GeoPoint location,
    Timestamp timestamp,
  ) async {
    try {
      await _firestore.collection(Officer.collectionName).doc(officerId).update(
        {'location': location, 'locationUpdatedAt': timestamp},
      );
    } catch (e) {
      throw Exception('Failed to update location for officer $officerId: $e');
    }
  }
}
