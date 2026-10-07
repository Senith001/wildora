# Environment Setup - Wildora Flutter App

## Overview

Wildora is a small Flutter application designed with a minimal maintainable architecture. This document covers the initial environment setup phase only, establishing the foundation for future feature development.

## Environment

- **Flutter**: 3.47.6 (stable)
- **Dart**: 3.13.5
- **Platforms**: Web + Android
- **iOS/macOS**: NOT configured (Xcode/CocoaPods unavailable in development environment)

## Project Structure

The project follows a clean layered architecture with placeholders for future expansion:

```
lib/
├── main.dart                 # Entry point with mobile preview wrapper
└── src/
    ├── app/                  # App-level widgets (root App, theme, routing)
    ├── core/                 # Shared cross-cutting code (constants, utils, config)
    │   └── config/          # App configuration and environment settings
    ├── data/                # Data layer placeholder (future Drift/SQLite + Supabase)
    └── features/            # Feature modules placeholder
```

### Directory Purposes

- **`app/`**: Contains root application widget and theme configuration
- **`core/`**: Shared utilities and cross-cutting concerns
  - **`core/config/`**: Environment settings and Firebase configuration
- **`data/`**: Placeholder for future data sources with Firebase integration
- **`features/`**: Placeholder for feature modules (each will get its own folder)

**Note**: All data, config, and features directories currently contain README placeholders only.

## Mobile-Sized Web Preview

The app includes a development aid (`lib/src/app/mobile_preview.dart`) for consistent mobile UI testing:

- **Web behavior**: Renders the app in a centered 390×844px phone frame with MediaQuery override
- **Mobile behavior**: Renders full-screen normally
- **Purpose**: Provides consistent mobile viewport in desktop browsers during development

The `MobilePreview` widget wraps the main app and automatically detects web vs. mobile platforms using `kIsWeb`.

## Running the Application

### Command Line
- **Web (Chrome)**: `flutter run -d chrome`
- **Android**: `flutter run`

### VS Code Launch Configurations
Available configurations in `.vscode/launch.json`:
- Wildora (Web - Chrome)
- Wildora (Web - Mobile Size)
- Wildora (Android)
- Wildora (Release)

## Building

Verified working build commands:
- **Web**: `flutter build web`
- **Android Debug**: `flutter build apk --debug`

## Current Implementation

The app currently displays a minimal "Wildora" text in the center of the screen. Key files:
- `lib/main.dart`: Entry point wrapping app in MobilePreview
- `lib/src/app/app.dart`: Root MaterialApp with basic theme
- `lib/src/app/mobile_preview.dart`: Web mobile viewport constraint widget
- `test/widget_test.dart`: Basic app loading test

## Planned Integrations (NOT Yet Implemented)

- **Firebase**: Backend services for authentication, Firestore database, Storage, and FCM (foundation integrated, Auth/Firestore/Storage/FCM planned)
- **Firestore Data Model**: Foundation exists for animals, highRiskZones, and alerts
- **Local/offline storage (Drift/SQLite)**: Under consideration for offline-first capabilities

**Important**: No backend connectivity, authentication, database models, API calls, screens, or business logic have been implemented yet. This is purely the foundational structure.

## Development Setup

- VS Code settings configured for Flutter development (format on save, dart line length 80)
- Standard Flutter project dependencies: `cupertino_icons`, `flutter_lints`
- Git repository initialized with conventional commits on main branch

## Git History

Project was set up via conventional commits merged from an isolated spec worktree:
- Initialize project structure
- Add mobile preview functionality  
- Configure VS Code settings
- Create README and documentation

All changes were properly merged to main branch following conventional commit standards.