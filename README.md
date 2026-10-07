# Wildora

A Flutter application with minimal maintainable architecture.

## Prerequisites

- Flutter 3.47.6 (stable)
- Dart 3.13.5

## Running the App

**Web (Chrome):**
```bash
flutter run -d chrome
```
*Note: Web runs in a mobile-sized preview frame for development convenience.*

**Android:**
```bash
flutter run
```

## Project Structure

```
lib/
├── main.dart                 # Entry point with mobile preview wrapper
└── src/
    ├── app/                  # App-level widgets (root App, theme, routing)
    ├── core/                 # Shared cross-cutting code (constants, utils, config)
    │   └── config/          # App configuration and environment settings
    ├── data/                # Data layer placeholder (future Firebase integration)
    └── features/            # Feature modules placeholder
```

## Firebase Setup

Firebase is the backend for Wildora. The project is configured via the official FlutterFire approach (`flutterfire configure`), which generated `lib/firebase_options.dart`. Firebase is initialized once at startup from `lib/src/core/firebase/firebase_initializer.dart` (called in `main.dart` before `runApp`), keeping it isolated from the UI layer.

**Platforms configured:** Android and Web

**Planned Firebase services:** Foundation prepared, but NOT yet implemented in features:
- Firebase Authentication
- Cloud Firestore
- Firebase Storage
- Firebase Cloud Messaging (FCM)

### For another developer

1. Install Flutter 3.47.6
2. Run `flutter pub get`
3. Native config files like `android/app/google-services.json` are gitignored and NOT committed. A developer with access to the WILDORA Firebase project must:
   - Run `dart pub global activate flutterfire_cli`
   - Run `flutterfire configure --project=<wildora project id> --platforms=android,web` to regenerate their own `firebase_options.dart` + `google-services.json`
   - OR obtain these files from the project owner
4. Run `flutter run -d chrome` or `flutter run`

**Security note:** `firebase_options.dart` holds public client identifiers (safe to commit); real native config and any admin/service-account credentials are gitignored and must never be committed.

## Planned Integrations

- **Firebase**: Backend services (foundation integrated)
- **Local/offline storage**: Under consideration (Drift/SQLite)