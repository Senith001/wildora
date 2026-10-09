import 'package:flutter/material.dart';

import '../../data/repositories/user_preferences_repository.dart';

/// Controller for managing theme preferences across the app.
///
/// Uses ChangeNotifier to notify widgets when theme changes and
/// persists preferences to Firestore via UserPreferencesRepository.
/// Provides safe initialization that won't crash if Firestore fails.
class ThemeController extends ChangeNotifier {
  final UserPreferencesRepository _preferencesRepository;
  static const String _demoUserId = 'demo-user';

  ThemeMode _themeMode = ThemeMode.system;

  /// Creates ThemeController with injected UserPreferencesRepository.
  ///
  /// Repository is injected to support testing with fake implementations
  /// and avoid Firebase calls that could break tests.
  ThemeController(this._preferencesRepository);

  /// Current theme mode setting.
  ThemeMode get themeMode => _themeMode;

  /// Initialize theme by loading saved preference from Firestore.
  ///
  /// Safely handles Firestore read failures by defaulting to system theme.
  /// Call this once during app startup after Firebase initialization.
  Future<void> loadSavedTheme() async {
    try {
      final savedTheme = await _preferencesRepository.getThemeMode(_demoUserId);
      _themeMode = _parseThemeMode(savedTheme);
      notifyListeners();
    } catch (e) {
      // Gracefully handle Firestore failures by keeping system default
      // This ensures app works even when offline or Firestore unavailable
      _themeMode = ThemeMode.system;
      notifyListeners();
    }
  }

  /// Update theme mode and persist to Firestore.
  ///
  /// Updates in-memory state, notifies listeners for immediate UI update,
  /// then persists to Firestore as fire-and-forget (battery/write-light).
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners(); // Update UI immediately

    // Fire-and-forget persistence - don't wait or handle errors
    // to keep UI responsive and battery-friendly
    _preferencesRepository
        .setThemeMode(_demoUserId, _themeMode.name)
        .catchError((_) {
          // Silently ignore persistence errors - UI already updated
          // User will see their change immediately even if save fails
        });
  }

  /// Parse theme mode string from Firestore to ThemeMode enum.
  ThemeMode _parseThemeMode(String? themeString) {
    switch (themeString) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }
}
