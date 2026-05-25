# Developing Waddle View

## Mono-repo layout

- Application root: **`apps/waddle_display/`**
- Pi / ops docs: **`docs/pi/`**
- Install templates: **`deploy/linux-arm64/`**

## Pi / Linux ARM64 release (CI)

The **[`release-pi.yml`](../../.github/workflows/release-pi.yml)** job runs on **`ubuntu-22.04-arm`** inside a **`debian:bookworm-slim`** container so the Linux ARM64 binary matches **Raspberry Pi OS Bookworm** for **glibc** (≤ **2.36** symbol versions) and **shared-library SONAMEs** (for example **`libmpv.so.2`**). Do not switch the host runner to Ubuntu 24.04 without revisiting the glibc check in that workflow, and keep the container aligned with Bookworm (or bump the supported Pi OS) if you change the toolchain.

## Local development

- **Windows**: `flutter run -d windows` (GTK not required).
- **Linux / Pi**: `flutter run -d linux`.

From the app directory:

```bash
flutter pub get
flutter analyze
flutter test --coverage
dart run tool/coverage_check.dart --min=85 --target=90
```

After editing shared Drift schema, run from the **repository root** (see [`AGENTS.md`](../../AGENTS.md)):

```bash
cd packages/waddle_shared
dart run build_runner build --delete-conflicting-outputs
flutter test
cd ../..
```

## Agent rules

See [`AGENTS.md`](../../AGENTS.md) and [`.cursor/rules/waddle-view-flutter.mdc`](../../.cursor/rules/waddle-view-flutter.mdc).

## Secret storage on Linux

**Integration API keys** (OpenAI, Pexels, OpenWeatherMap, Finnhub, Flickr, etc.) are stored **encrypted in SQLite** (`integration_secrets`) and configured in **`apps/waddle_controller`** → **Integrations** (write-only over REST). Legacy **`WADDLE_DISPLAY_*` provider key env vars are deprecated and ignored at collect time** — see [`apps/waddle_display/.env.example`](../../apps/waddle_display/.env.example).

At runtime, [`ProviderConfigResolver`](../../packages/waddle_shared/lib/config/provider_config_resolver.dart) reads tokens from [`SecretStore`](../../packages/waddle_shared/lib/secrets/secret_store.dart) via [`readAccessTokenForIntegration`](../../packages/waddle_shared/lib/integration_accounts/integration_accounts_service.dart).

**OAuth** (Google Calendar, Microsoft Graph / OneDrive): access and refresh tokens also live in **`SecretStore`** (device-code sign-in in the app, or `waddlectl secrets set` on Linux). `flutter_secure_storage` expects **D-Bus** and a compatible **Secret Service** (e.g. gnome-keyring) on Linux. Minimal images may lack this; document a fallback for your deployment.

**OAuth public client ids** still use process env (or merged debug `.env`): **`WADDLE_DISPLAY_GOOGLE_CLIENT_ID`**, **`WADDLE_DISPLAY_MICROSOFT_GRAPH_CLIENT_ID`** — not SQLite.

**Display REST authentication** uses **adoption API keys** (`POST /v1/adoption/request` + confirm); see [`api.md`](api.md). **`waddle_instance.id`** in app support is the adoption HMAC secret (legacy **`waddle_api.key`** is renamed on upgrade) — not the bearer token.

### Configuring integrations as a developer

1. Run **`waddle_display`** and **`waddle_controller`**, adopt the display from the controller, then open **Integrations** and set each provider’s secret fields.
2. On Linux bundles, use **`waddlectl secrets set`** for OAuth tokens when the UI is unavailable.
3. **Tests**: use [`InMemorySecretStore`](../../packages/waddle_shared/lib/secrets/in_memory_secret_store.dart) or test helpers that seed `integration_secrets`; see [`provider_config_resolver_test.dart`](../../packages/waddle_shared/test/config/provider_config_resolver_test.dart).

### Example: joke provider (`joke_openai`)

| What | Value |
|------|--------|
| Provider id | `joke_openai` |
| API token | Controller **Integrations** → OpenAI secret (encrypted in SQLite) |
| Non-secret config | `integrations.config_json` — model, prompts ([`JokeProviderExtraConfig`](../../packages/waddle_integrations/lib/joke_openai/joke_provider_extra_config.dart)) |

If no token is configured, [`collect`](../../packages/waddle_integrations/lib/joke_openai/joke_data_provider.dart) exits early and logs that the API token is missing.
