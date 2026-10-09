import 'package:flutter/material.dart';

import 'src/app/app.dart';
import 'src/app/mobile_preview.dart';
import 'src/app/theme/theme_controller.dart';
import 'src/core/firebase/firebase_initializer.dart';
import 'src/data/repositories/user_preferences_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase first
  await FirebaseInitializer.ensureInitialized();

  // Create ThemeController with Firestore repository
  final userPreferencesRepository = FirestoreUserPreferencesRepository();
  final themeController = ThemeController(userPreferencesRepository);

  // Load saved theme (safely handles Firestore failures)
  await themeController.loadSavedTheme();

  runApp(MobilePreview(child: WildoraApp(themeController: themeController)));
}
