# Developing Waddle View

## Mono-repo layout

- Application root: **`apps/waddle_view/`**
- Pi / ops docs: **`docs/pi/`**
- Install templates: **`deploy/linux-arm64/`**

## Local development

- **Windows**: `flutter run -d windows` (GTK not required).
- **Linux / Pi**: `flutter run -d linux`.

From the app directory:

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test --coverage
dart run tool/coverage_check.dart --min=90
```

## Agent rules

See [`AGENTS.md`](../../AGENTS.md) and [`.cursor/rules/waddle-view-flutter.mdc`](../../.cursor/rules/waddle-view-flutter.mdc).

## Secret storage on Linux

`flutter_secure_storage` expects **D-Bus** and a compatible **Secret Service** (e.g. gnome-keyring). Minimal images may lack this; document a fallback for your deployment rather than storing secrets in SQLite.
