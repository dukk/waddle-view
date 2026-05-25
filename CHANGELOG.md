# Changelog

All notable changes to this project are documented here. Release binaries and auto-generated notes also appear on [GitHub Releases](https://github.com/dukk/waddle-view/releases).

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.0.0] - 2026-05-25

First public release of **Waddle View** — a reimagined TV dashboard stack (successor to [quackview](https://github.com/dukk/quackview)) with a Flutter display app, optional operator controller, and shared Drift persistence.

### Added

- **`waddle_display`**: Linux (Pi arm64) and Windows dev builds; SQLite or optional Postgres; local HTTPS REST API; slide rotator, ticker, overlays, data collection loop.
- **`waddle_controller`**: Operator SPA + optional BFF (Hono) with display proxy, integrations UI, backup/restore, Pi upgrade triggers.
- **`waddlectl`**: CLI for backups, secrets (OAuth), and operator tasks on Linux bundles.
- **Adoption API**: Device-style pairing (`POST /v1/adoption/request` + confirm on display) issuing `wd_` API keys (hashes stored only).
- **Encrypted integration secrets** in SQLite; configure via controller Integrations UI.
- **Built-in integrations** (`waddle_integrations`): weather, RSS, media providers, stocks, jokes/trivia, calendars, and more.
- **Display plugin SDK** (`waddle_plugin_sdk` **0.1.0** — pre-1.0 API stability).
- **CI**: Multi-platform compile smoke, tests, ≥80% coverage gate on core packages; tag-driven **Release** workflow for tarballs, zips, APK smoke, macOS/iOS bundles, controller Docker image.
- **Deploy**: Pi/linux-arm64 install scripts, one-line `install-latest-release.sh`, remote upgrade helper.

### Security

- Default REST bind `0.0.0.0:8787` with self-signed TLS; LAN-oriented CORS and adoption challenge on display.
- See [SECURITY.md](SECURITY.md) for reporting and hardening guidance.

### Known limitations

- **License**: [ONC v1.0](LICENSE) — non-commercial use only unless you obtain a commercial license.
- **Apple sign-in**: `WADDLE_DISPLAY_APPLE_CLIENT_ID` routes return **501** until implemented.
- **Viewer self-registration**: `POST /v1/auth/register-viewer` is documented in env catalog but not implemented on the display API.
- **Plugin SDK**: version **0.1.0**; breaking changes may occur before 1.0.
- **Controller UI tests**: pages/layout/components excluded from the 80% coverage floor until component tests land.
- **Android / iOS**: CI compile artifacts only; not primary product targets.

[1.0.0]: https://github.com/dukk/waddle-view/releases/tag/v1.0.0
