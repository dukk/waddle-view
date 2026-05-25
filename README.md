# Waddle View

A reimagined [quackview](https://github.com/dukk/quackview) focused on better visual performance on Raspberry Pi, with a completely different architecture and technology stack.

TV dashboard and related applications for Raspberry Pi and development machines.

[![CI — waddle_display](https://github.com/dukk/waddle-view/actions/workflows/ci.yml/badge.svg)](https://github.com/dukk/waddle-view/actions/workflows/ci.yml)

## Applications

| Path | Description |
| --- | --- |
| [`apps/waddle_display`](apps/waddle_display) | Flutter **Linux** (and **Windows** for dev) TV dashboard: SQLite persistence, ticker, overlay alerts, local REST API, data collection loop. Architecture: [`apps/waddle_display/ARCHITECTURE.md`](apps/waddle_display/ARCHITECTURE.md). |
| [`apps/waddle_controller`](apps/waddle_controller) | Operator web UI (optional; separate Node/npm setup). Docker image published on [CI and Release](apps/waddle_controller/README.md#deploy-from-github-builds). |
| [`apps/waddlectl`](apps/waddlectl) | CLI helper bundled with Linux releases ([README](apps/waddlectl/README.md)). |
| [`packages/waddle_shared`](packages/waddle_shared) | Drift schema, persistence, and shared libraries (codegen runs here). |
| [`packages/waddle_integrations`](packages/waddle_integrations) | Built-in integration data collectors. |

## Quick start (dashboard app)

This repo is a Pub **workspace** ([`pubspec.yaml`](pubspec.yaml) at the root). Resolve dependencies once from the repository root, then generate Drift code in the shared package before building the display app.

From the **repository root**:

```bash
flutter pub get
cd packages/waddle_shared
dart run build_runner build --delete-conflicting-outputs
```

After editing `packages/waddle_shared/lib/persistence/` (schema or tables), re-run the `build_runner` line.

Prerequisites (Visual Studio ATL, Windows Developer Mode, Linux GTK/WebKit deps, and more) are documented in [`apps/waddle_display/README.md`](apps/waddle_display/README.md).

### Run locally

From the repository root (or `cd apps/waddle_display`):

```bash
flutter devices
flutter run -d windows    # or: flutter run -d linux
# flutter run --profile
# flutter run --release
```

**Debug** is the default for `flutter run` (hot reload, asserts). **Release** matches production behavior most closely (e.g. Linux window policy). Built artifacts: `flutter build windows --release` / `flutter build linux --release`.

See [`apps/waddle_display/README.md`](apps/waddle_display/README.md) for REST bind address, API key file location, local bundle paths, and Pi deployment summary.

## Quality checks (optional)

**Fast inner loop** (no coverage; skips `pub get` / `build_runner` when lockfiles and schema are unchanged):

```bash
python scripts/waddle_checks.py fast
```

**CI parity** (before merge): see [`AGENTS.md`](AGENTS.md) and [`.cursor/skills/run-waddle-checks/SKILL.md`](.cursor/skills/run-waddle-checks/SKILL.md). In short: `flutter pub get` and `build_runner` in `packages/waddle_shared`, then tests in `waddle_shared`, `waddle_integrations`, `waddle_plugin_sdk`, and `apps/waddle_display`, with a merged coverage gate:

```bash
python scripts/waddle_checks.py full
```

Coverage floor: **≥ 80%** line coverage on gated libs (display, shared, plugin SDK; see `apps/waddle_display/tool/coverage_check.dart`). **90%** is the aspirational target (warn only between 80% and 90%).

## Raspberry Pi

See [`docs/pi/`](docs/pi/) for using the release artifact, upgrading, development, and HTTP API. Install the latest release with [`deploy/install-latest-release.sh`](deploy/install-latest-release.sh) (documented in [`docs/pi/using-the-image.md`](docs/pi/using-the-image.md)).

## License

This project is released under the **[Open Non-Commercial License (ONC) v1.0](LICENSE)**. You may use, modify, and distribute it for **non-commercial** purposes with attribution. **Commercial use** requires a separate agreement — contact **dukk@dukk.org** (see LICENSE section 6).

## Contributing and security

- [CONTRIBUTING.md](CONTRIBUTING.md) — development setup, quality checks, releases
- [SECURITY.md](SECURITY.md) — vulnerability reporting and deployment threat model
- [CHANGELOG.md](CHANGELOG.md) — release history
- [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)

For large code changes, also read [`AGENTS.md`](AGENTS.md). Optional Cursor rules live under [`.cursor/`](.cursor/) (see [`.cursor/README.md`](.cursor/README.md)).
