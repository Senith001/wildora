import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/alert.dart';
import '../models/alert_recipient.dart';

/// Repository interface for AlertRecipient operations.
///
/// Manages fan-out delivery of alerts to individual officers.
/// Recipients are stored as subcollection under alerts/{alertId}/recipients.
abstract class AlertRecipientRepository {
  /// Fan-out alert to multiple recipients (batch write)
  Future<void> fanOut(String alertId, List<AlertRecipient> recipients);

  /// Watch recipients for a specific officer (for their alert dashboard)
  Stream<List<AlertRecipient>> watchRecipientsForOfficer(String officerId);

  /// Watch recipients for a specific alert (for admin/debug)
  Stream<List<AlertRecipient>> watchForAlert(String alertId);

  /// Mark alert as read by specific officer
  Future<void> markRead(String alertId, String officerId);
}

/// Firestore implementation of AlertRecipientRepository.
///
/// Uses cloud_firestore with alerts/{alertId}/recipients subcollection.
/// Implements efficient batch writes for fan-out operations.
class FirestoreAlertRecipientRepository implements AlertRecipientRepository {
  final FirebaseFirestore _firestore;

  FirestoreAlertRecipientRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> fanOut(String alertId, List<AlertRecipient> recipients) async {
    if (recipients.isEmpty) return;

    try {
      // Use batch write for atomic fan-out
      final batch = _firestore.batch();

      for (final recipient in recipients) {
        final recipientRef = _firestore
            .collection(Alert.collectionName)
            .doc(alertId)
            .collection(AlertRecipient.collectionName)
            .doc(recipient.officerId);

        batch.set(recipientRef, recipient.toMap());
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to fan out alert $alertId to recipients: $e');
    }
  }

  @override
  Stream<List<AlertRecipient>> watchRecipientsForOfficer(String officerId) {
    try {
      // Use collection group query to find all recipient docs for this officer
      return _firestore
          .collectionGroup(AlertRecipient.collectionName)
          .where('officerId', isEqualTo: officerId)
          .orderBy('readAt', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs.map((doc) {
              return AlertRecipient.fromMap(doc.id, doc.data());
            }).toList();
          });
    } catch (e) {
      throw Exception('Failed to watch recipients for officer $officerId: $e');
    }
  }

  @override
  Stream<List<AlertRecipient>> watchForAlert(String alertId) {
    try {
      return _firestore
          .collection(Alert.collectionName)
          .doc(alertId)
          .collection(AlertRecipient.collectionName)
          .orderBy('officerName')
          .snapshots()
          .map((snapshot) {
            return snapshot.docs.map((doc) {
              return AlertRecipient.fromMap(doc.id, doc.data());
            }).toList();
          });
    } catch (e) {
      throw Exception('Failed to watch recipients for alert $alertId: $e');
    }
  }

  @override
  Future<void> markRead(String alertId, String officerId) async {
    try {
      await _firestore
          .collection(Alert.collectionName)
          .doc(alertId)
          .collection(AlertRecipient.collectionName)
          .doc(officerId)
          .update({
            'deliveryStatus': 'read',
            'readAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      throw Exception(
        'Failed to mark alert $alertId as read for officer $officerId: $e',
      );
    }
  }
}
