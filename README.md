# Waddle View



This is a re-imagioned [quackview](https://github.com/dukk/quackview) with the goal of better visual performance on the raspberry pi. It's using a completly different architecture and technology stack.

TV dashboard and related applications for Raspberry Pi and development machines.

## Applications


| Path                                   | Description                                                                                                                                                                                                                       |
| -------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `[apps/waddle_view](apps/waddle_view)` | Flutter **Linux** (and **Windows** for dev) TV dashboard: SQLite persistence, ticker, overlay alerts, local REST API, data collection loop. Architecture: `[apps/waddle_view/ARCHITECTURE.md](apps/waddle_view/ARCHITECTURE.md)`. |


## Quick start (dashboard app)

```bash
cd apps/waddle_view
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test --coverage
dart run tool/coverage_check.dart --min=85
```

Coverage gate: **≥ 85%** line coverage on `lib/` (excluding `lib/persistence/tables.dart` and `lib/main.dart` from the gate script; see `tool/coverage_check.dart`).

### Run in debug (or profile / release)

From `apps/waddle_view`:

```bash
flutter devices
flutter run -d windows    # or: flutter run -d linux
# flutter run --profile
# flutter run --release
```

**Debug** is the default for `flutter run` (hot reload, asserts). **Release** matches production behavior most closely (e.g. Linux window policy). Built artifacts: `flutter build windows --release` / `flutter build linux --release`.

See `**[apps/waddle_view/README.md](apps/waddle_view/README.md)`** for REST bind address, API key file location, local bundle paths, and Pi deployment summary.

## Raspberry Pi

See `[docs/pi/](docs/pi/)` for using the release artifact, upgrading, development, and HTTP API.

## Agent / contributor rules

Read `[AGENTS.md](AGENTS.md)` and `[.cursor/rules/](.cursor/rules/)` before large changes.