import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model for Officer collection.
///
/// Officers represent both Rangers and Community Liaison Officers (CLOs).
/// Includes location data for proximity-based alert routing and FCM tokens
/// for push notifications.
class Officer {
  static const String collectionName = 'officers';

  final String officerId;
  final String name;
  final String role; // 'ranger' | 'clo'
  final String? contactNo; // Rangers have it, CLOs may not
  final GeoPoint? location; // For proximity filtering
  final Timestamp? locationUpdatedAt; // For freshness checking (Rangers only)
  final List<String> fcmTokens; // For push notifications

  const Officer({
    required this.officerId,
    required this.name,
    required this.role,
    this.contactNo,
    this.location,
    this.locationUpdatedAt,
    this.fcmTokens = const [],
  });

  factory Officer.fromMap(String id, Map<String, dynamic> map) {
    return Officer(
      officerId: id,
      name: map['name'] as String,
      role: map['role'] as String,
      contactNo: map['contactNo'] as String?,
      location: map['location'] as GeoPoint?,
      locationUpdatedAt: map['locationUpdatedAt'] as Timestamp?,
      fcmTokens: List<String>.from(map['fcmTokens'] as List? ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'officerId': officerId,
      'name': name,
      'role': role,
      'contactNo': contactNo,
      'location': location,
      'locationUpdatedAt': locationUpdatedAt,
      'fcmTokens': fcmTokens,
    };
  }

  /// Create a copy with updated fields
  Officer copyWith({
    String? name,
    String? role,
    String? contactNo,
    GeoPoint? location,
    Timestamp? locationUpdatedAt,
    List<String>? fcmTokens,
  }) {
    return Officer(
      officerId: officerId,
      name: name ?? this.name,
      role: role ?? this.role,
      contactNo: contactNo ?? this.contactNo,
      location: location ?? this.location,
      locationUpdatedAt: locationUpdatedAt ?? this.locationUpdatedAt,
      fcmTokens: fcmTokens ?? this.fcmTokens,
    );
  }
}
