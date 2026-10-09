import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_preferences.dart';

/// Repository interface for UserPreferences operations.
///
/// Manages theme preferences and other user-specific settings.
/// Uses Firestore for cross-device sync and offline caching.
abstract class UserPreferencesRepository {
  /// Get theme mode for user
  Future<String?> getThemeMode(String userId);

  /// Watch theme mode for real-time updates
  Stream<String?> watchThemeMode(String userId);

  /// Set theme mode for user
  Future<void> setThemeMode(String userId, String mode);
}

/// Firestore implementation of UserPreferencesRepository.
///
/// Uses cloud_firestore with userPreferences collection.
/// Provides theme persistence with cross-device sync.
class FirestoreUserPreferencesRepository implements UserPreferencesRepository {
  final FirebaseFirestore _firestore;

  FirestoreUserPreferencesRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<String?> getThemeMode(String userId) async {
    try {
      final doc = await _firestore
          .collection(UserPreferences.collectionName)
          .doc(userId)
          .get();

      if (!doc.exists || doc.data() == null) {
        return null; // Default to system theme
      }

      final preferences = UserPreferences.fromMap(doc.id, doc.data()!);
      return preferences.themeMode;
    } catch (e) {
      throw Exception('Failed to get theme mode for user $userId: $e');
    }
  }

  @override
  Stream<String?> watchThemeMode(String userId) {
    try {
      return _firestore
          .collection(UserPreferences.collectionName)
          .doc(userId)
          .snapshots()
          .map((doc) {
            if (!doc.exists || doc.data() == null) {
              return null; // Default to system theme
            }
            final preferences = UserPreferences.fromMap(doc.id, doc.data()!);
            return preferences.themeMode;
          });
    } catch (e) {
      throw Exception('Failed to watch theme mode for user $userId: $e');
    }
  }

  @override
  Future<void> setThemeMode(String userId, String mode) async {
    try {
      final preferences = UserPreferences(
        userId: userId,
        themeMode: mode,
        lastUpdated: Timestamp.now(),
      );

      await _firestore
          .collection(UserPreferences.collectionName)
          .doc(userId)
          .set(preferences.toMap(), SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to set theme mode for user $userId: $e');
    }
  }
}
