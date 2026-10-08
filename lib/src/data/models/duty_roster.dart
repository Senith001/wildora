import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model for DutyRoster collection.
///
/// Tracks which Rangers are on duty for a given date.
/// Used for proximity-based filtering (only on-duty Rangers get alerts).
/// CLOs are always considered available and don't need duty status.
class DutyRoster {
  static const String collectionName = 'dutyRoster';

  final String date; // Document ID in "yyyy-MM-dd" format
  final List<String> onDutyRangerIds; // Officer IDs on duty this day
  final Timestamp lastUpdated;

  const DutyRoster({
    required this.date,
    required this.onDutyRangerIds,
    required this.lastUpdated,
  });

  factory DutyRoster.fromMap(String id, Map<String, dynamic> map) {
    return DutyRoster(
      date: id,
      onDutyRangerIds: List<String>.from(map['onDutyRangerIds'] as List? ?? []),
      lastUpdated: map['lastUpdated'] as Timestamp,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'onDutyRangerIds': onDutyRangerIds,
      'lastUpdated': lastUpdated,
    };
  }

  /// Create a copy with updated fields
  DutyRoster copyWith({List<String>? onDutyRangerIds, Timestamp? lastUpdated}) {
    return DutyRoster(
      date: date,
      onDutyRangerIds: onDutyRangerIds ?? this.onDutyRangerIds,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  /// Check if a specific officer is on duty
  bool isOnDuty(String officerId) {
    return onDutyRangerIds.contains(officerId);
  }
}
