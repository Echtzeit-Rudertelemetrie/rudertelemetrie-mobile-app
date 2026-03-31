# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
flutter pub get       # Install dependencies
flutter run           # Run the app
flutter test          # Run all tests
flutter test test/widget_test.dart  # Run a single test file
flutter analyze       # Static analysis / lint
flutter build apk     # Build for Android
flutter build ios     # Build for iOS
```

## Architecture

This is a Flutter app for rowing telemetry. State management uses **Provider** with `ChangeNotifier`.

### Data flow

Models (`lib/models/`) extend `ChangeNotifier`. Providers (`lib/providers/`) instantiate them as `ChangeNotifierProvider` and are registered in `main.dart` via `MultiProvider`. Widgets consume state via:
- `context.watch<T>()` — subscribe and rebuild on changes
- `context.read<T>()` — write/call methods without subscribing

### Navigation

Standard `Navigator.push/pop` — no routing package. Screens live in `lib/screens/`, reusable widgets in `lib/components/`.

### UI framework

Uses **Forui** (`forui` package) for all UI components — `FScaffold`, `FHeader`, `FButton`, `FSlider`, `FTileGroup`, etc. `forui.yaml` configures code generation for custom snippets/styles (output: `lib/theme/`). The theme is set up in `main.dart` using `FTheme` with a platform-aware variant (`touch` for mobile, `desktop` otherwise).

## Code Style

- Functions should do one thing. If you need "and" to describe it, split it.
- Max ~15–20 lines per function. Decompose if longer.
- Names must express intent without comments.
- Do not write comments unless absolutely necessary (e.g., explaining non-obvious algorithms or critical warnings).
- Prefer early returns over nested conditionals.
- Before finishing, scan for duplicated logic and extract it.
