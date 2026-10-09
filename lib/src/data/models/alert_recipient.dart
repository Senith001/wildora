import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model for AlertRecipient subcollection.
///
/// Tracks per-officer delivery status for alert fan-out notifications.
/// Stored as subcollection under alerts/{alertId}/recipients/{officerId}.
class AlertRecipient {
  static const String collectionName = 'recipients';

  final String officerId;
  final String officerName; // Denormalized for display
  final String role; // 'ranger' | 'clo' (denormalized)
  final String deliveryStatus; // 'pending' | 'delivered' | 'read'
  final Timestamp? readAt;
  final List<String> notifiedChannels; // ['inApp', 'fcm']

  const AlertRecipient({
    required this.officerId,
    required this.officerName,
    required this.role,
    required this.deliveryStatus,
    this.readAt,
    this.notifiedChannels = const [],
  });

  factory AlertRecipient.fromMap(String id, Map<String, dynamic> map) {
    return AlertRecipient(
      officerId: id,
      officerName: map['officerName'] as String,
      role: map['role'] as String,
      deliveryStatus: map['deliveryStatus'] as String,
      readAt: map['readAt'] as Timestamp?,
      notifiedChannels: List<String>.from(
        map['notifiedChannels'] as List? ?? [],
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'officerId': officerId,
      'officerName': officerName,
      'role': role,
      'deliveryStatus': deliveryStatus,
      'readAt': readAt,
      'notifiedChannels': notifiedChannels,
    };
  }

  /// Create a copy with updated fields
  AlertRecipient copyWith({
    String? officerName,
    String? role,
    String? deliveryStatus,
    Timestamp? readAt,
    List<String>? notifiedChannels,
  }) {
    return AlertRecipient(
      officerId: officerId,
      officerName: officerName ?? this.officerName,
      role: role ?? this.role,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      readAt: readAt ?? this.readAt,
      notifiedChannels: notifiedChannels ?? this.notifiedChannels,
    );
  }
}
