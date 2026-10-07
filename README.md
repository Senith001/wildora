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
    ├── data/                # Data layer placeholder (future Drift/SQLite + Supabase)
    └── features/            # Feature modules placeholder
```

## Planned Integrations

- **Supabase**: Backend services (not yet integrated)
- **Drift/SQLite**: Local database (not yet integrated)