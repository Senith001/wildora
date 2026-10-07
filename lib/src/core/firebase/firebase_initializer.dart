import 'package:firebase_core/firebase_core.dart';
import 'package:wildora/firebase_options.dart';

/// Firebase bootstrap and initialization.
///
/// This class provides the single entry point for Firebase setup,
/// keeping Firebase configuration isolated from the UI layer.
/// All Firebase initialization should go through this class.
class FirebaseInitializer {
  /// Initializes Firebase with the current platform configuration.
  ///
  /// This method is idempotent - it can be called multiple times safely
  /// without throwing errors on hot restart or double initialization.
  static Future<void> ensureInitialized() async {
    // Return early if Firebase is already initialized
    if (Firebase.apps.isNotEmpty) return;

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}
