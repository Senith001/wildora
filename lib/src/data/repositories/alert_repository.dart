import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/alert.dart';

/// Repository interface for Alert operations.
///
/// Provides dependency inversion for testability - domain logic depends on
/// this interface, not concrete Firestore implementation.
abstract class AlertRepository {
  /// Create a new alert and return its ID
  Future<String> create(Alert alert);

  /// Watch active alerts for real-time updates
  Stream<List<Alert>> watchActiveAlerts();

  /// Stream alerts for real-time updates
  Stream<List<Alert>> streamAlerts();

  /// Get alert by ID
  Future<Alert?> getById(String alertId);

  /// Watch alert by ID for real-time updates
  Stream<Alert?> watchById(String alertId);

  /// Claim response to an alert (atomic first-responder-wins)
  /// Only sets responding fields if responseStatus is 'unclaimed'
  /// Returns true if successfully claimed, false if already claimed
  Future<bool> claimResponse(
    String alertId,
    String officerId,
    String officerName,
  );

  /// Acknowledge an alert (mark as acknowledged)
  Future<void> acknowledge(String alertId);

  /// Resolve response for an alert
  Future<void> resolveResponse(String alertId);
}

/// Firestore implementation of AlertRepository.
///
/// Uses cloud_firestore for persistence with alerts collection.
/// Implements atomic claim response using Firestore transactions.
class FirestoreAlertRepository implements AlertRepository {
  final FirebaseFirestore _firestore;

  FirestoreAlertRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<String> create(Alert alert) async {
    try {
      final docRef = await _firestore
          .collection(Alert.collectionName)
          .add(alert.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create alert: $e');
    }
  }

  @override
  Stream<List<Alert>> watchActiveAlerts() {
    try {
      return _firestore
          .collection(Alert.collectionName)
          .where('status', isEqualTo: 'active')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs.map((doc) {
              return Alert.fromMap(doc.id, doc.data());
            }).toList();
          });
    } catch (e) {
      throw Exception('Failed to watch active alerts: $e');
    }
  }

  @override
  Stream<List<Alert>> streamAlerts() {
    try {
      return _firestore
          .collection(Alert.collectionName)
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs.map((doc) {
              return Alert.fromMap(doc.id, doc.data());
            }).toList();
          });
    } catch (e) {
      throw Exception('Failed to stream alerts: $e');
    }
  }

  @override
  Future<Alert?> getById(String alertId) async {
    try {
      final doc = await _firestore
          .collection(Alert.collectionName)
          .doc(alertId)
          .get();

      if (!doc.exists || doc.data() == null) {
        return null;
      }

      return Alert.fromMap(doc.id, doc.data()!);
    } catch (e) {
      throw Exception('Failed to get alert $alertId: $e');
    }
  }

  @override
  Stream<Alert?> watchById(String alertId) {
    try {
      return _firestore
          .collection(Alert.collectionName)
          .doc(alertId)
          .snapshots()
          .map((doc) {
            if (!doc.exists || doc.data() == null) {
              return null;
            }
            return Alert.fromMap(doc.id, doc.data()!);
          });
    } catch (e) {
      throw Exception('Failed to watch alert $alertId: $e');
    }
  }

  @override
  Future<bool> claimResponse(
    String alertId,
    String officerId,
    String officerName,
  ) async {
    try {
      final result = await _firestore.runTransaction<bool>((transaction) async {
        final alertRef = _firestore
            .collection(Alert.collectionName)
            .doc(alertId);
        final alertDoc = await transaction.get(alertRef);

        if (!alertDoc.exists || alertDoc.data() == null) {
          throw Exception('Alert not found');
        }

        final alertData = alertDoc.data()!;
        final currentResponseStatus =
            alertData['responseStatus'] as String? ?? 'unclaimed';

        // Only allow claiming if currently unclaimed
        if (currentResponseStatus != 'unclaimed') {
          return false; // Already claimed by another officer
        }

        // Claim the response atomically
        transaction.update(alertRef, {
          'responseStatus': 'responding',
          'respondingOfficerId': officerId,
          'respondingOfficerName': officerName,
          'respondingAt': FieldValue.serverTimestamp(),
        });

        return true; // Successfully claimed
      });

      return result;
    } catch (e) {
      throw Exception('Failed to claim response for alert $alertId: $e');
    }
  }

  @override
  Future<void> acknowledge(String alertId) async {
    try {
      await _firestore.collection(Alert.collectionName).doc(alertId).update({
        'status': 'acknowledged',
      });
    } catch (e) {
      throw Exception('Failed to acknowledge alert $alertId: $e');
    }
  }

  @override
  Future<void> resolveResponse(String alertId) async {
    try {
      await _firestore.collection(Alert.collectionName).doc(alertId).update({
        'responseStatus': 'resolved',
      });
    } catch (e) {
      throw Exception('Failed to resolve response for alert $alertId: $e');
    }
  }
}
