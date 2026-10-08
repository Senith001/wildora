import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model for UserPreferences collection.
///
/// Stores user-specific preferences like theme mode.
/// Uses Firestore for cross-device sync and offline caching.
class UserPreferences {
  static const String collectionName = 'userPreferences';

  final String userId;
  final String themeMode; // 'system' | 'light' | 'dark'
  final Timestamp lastUpdated;

  const UserPreferences({
    required this.userId,
    required this.themeMode,
    required this.lastUpdated,
  });

  factory UserPreferences.fromMap(String id, Map<String, dynamic> map) {
    return UserPreferences(
      userId: id,
      themeMode: map['themeMode'] as String,
      lastUpdated: map['lastUpdated'] as Timestamp,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'themeMode': themeMode,
      'lastUpdated': lastUpdated,
    };
  }

  /// Create a copy with updated fields
  UserPreferences copyWith({String? themeMode, Timestamp? lastUpdated}) {
    return UserPreferences(
      userId: userId,
      themeMode: themeMode ?? this.themeMode,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
