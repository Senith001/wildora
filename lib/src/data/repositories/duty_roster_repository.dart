import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/duty_roster.dart';

/// Repository interface for DutyRoster operations.
///
/// Manages duty roster data using date-keyed documents (yyyy-MM-dd format).
/// Used for proximity-based filtering to only alert on-duty Rangers.
abstract class DutyRosterRepository {
  /// Get duty roster for specific date (yyyy-MM-dd format)
  Future<DutyRoster?> getByDate(String date);
}

/// Firestore implementation of DutyRosterRepository.
///
/// Uses cloud_firestore with dutyRoster collection.
/// Documents are keyed by date strings in yyyy-MM-dd format.
class FirestoreDutyRosterRepository implements DutyRosterRepository {
  final FirebaseFirestore _firestore;

  FirestoreDutyRosterRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<DutyRoster?> getByDate(String date) async {
    try {
      final doc = await _firestore
          .collection(DutyRoster.collectionName)
          .doc(date)
          .get();

      if (!doc.exists || doc.data() == null) {
        return null;
      }

      return DutyRoster.fromMap(doc.id, doc.data()!);
    } catch (e) {
      throw Exception('Failed to get duty roster for date $date: $e');
    }
  }
}
