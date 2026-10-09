import 'package:flutter/material.dart';

import '../features/home/home_screen.dart';
import 'app_router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

/// The root application widget for Wildora with dependency injection.
class WildoraApp extends StatelessWidget {
  final ThemeController themeController;
  final AppRouter? router;
  late final AppRouter _appRouter;

  WildoraApp({super.key, required this.themeController, this.router}) {
    // Use provided router or create with Firestore dependencies
    _appRouter =
        router ??
        AppRouter.createWithFirestoreDependencies(
          themeController: themeController,
        );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) {
        return MaterialApp(
          title: 'Wildora',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeController.themeMode,
          onGenerateRoute: _appRouter.onGenerateRoute,
          home: const HomeScreen(),
        );
      },
    );
  }
}
