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
dart run tool/coverage_check.dart --min=90
```

After editing shared Drift schema, run from the **repository root** (see [`AGENTS.md`](../../AGENTS.md)):

```bash
dart run build_runner build --delete-conflicting-outputs -C packages/waddle_shared
cd packages/waddle_shared
dart test
cd ../..
```

## Agent rules

See [`AGENTS.md`](../../AGENTS.md) and [`.cursor/rules/waddle-view-flutter.mdc`](../../.cursor/rules/waddle-view-flutter.mdc).

## Secret storage on Linux

`flutter_secure_storage` expects **D-Bus** and a compatible **Secret Service** (e.g. gnome-keyring) for **Google Calendar** and **Microsoft Graph** OAuth token persistence. Minimal images may lack this; document a fallback for your deployment rather than storing those tokens in SQLite.

**Static provider API keys** (OpenAI for jokes/trivia, Pexels, Finnhub, OpenWeatherMap, Flickr, etc.) are **not** stored in `SecretStore`; they are read from **environment variables** merged at startup (`Platform.environment` plus debug `.env` — see [`mergeBootstrapEnv`](../../apps/waddle_display/lib/config/dev_dotenv_secrets.dart) and [`provider_access_token_env.dart`](../../packages/waddle_shared/lib/config/provider_access_token_env.dart)).

## Joke data provider (OpenAI API key)

The joke collector ([`JokeDataProvider`](../../apps/waddle_display/lib/data/providers/joke/joke_data_provider.dart)) calls the OpenAI HTTP API using a bearer token. Tokens **must not** live in SQLite ([`AGENTS.md`](../../AGENTS.md)). At runtime, [`ProviderConfigResolver`](../../packages/waddle_shared/lib/config/provider_config_resolver.dart) fills `ProviderRuntimeConfig.accessToken` from the merged **env map** (not from `SecretStore`).

| What | Value |
|------|--------|
| Provider id (also `provider_settings.id`) | `jokes` (see [`kJokeProviderId`](../../apps/waddle_display/lib/data/providers/joke/joke_data_provider.dart)) |
| Env resolution | [`resolveProviderAccessTokenFromEnv`](../../packages/waddle_shared/lib/config/provider_access_token_env.dart) for `jokes` — e.g. **`OPENAI_API_KEY`**, **`WADDLE_JOKES_ACCESS_TOKEN`**, or generic **`WADDLE_PROVIDER_ACCESS_TOKEN_JOKES`** |
| Non-secret config | `provider_settings` row for `jokes`: `base_url` (optional override; default API root is defined on the provider), `config_json` for model and prompts — see seed and [`JokeProviderExtraConfig`](../../apps/waddle_display/lib/data/providers/joke/joke_provider_extra_config.dart) |

If no token is resolved (null or empty), [`collect`](../../apps/waddle_display/lib/data/providers/joke/joke_data_provider.dart) exits early and logs that the API token is missing.

### How to set the key as a developer

The UI does not expose a form for static provider API keys. Recommended onboarding paths:

1. **`.env` file (debug)** — In **debug** desktop/server builds only (not web), the app loads a dotenv file from disk and merges it into the env map used by [`ProviderConfigResolver`](../../packages/waddle_shared/lib/config/provider_config_resolver.dart). Copy **[`apps/waddle_display/.env.example`](../../apps/waddle_display/.env.example)** to **`.env`** or **`.env.development`** in `apps/waddle_display/` (or add `assets/.env` / `assets/.env.development` in the same app directory). The first existing file in the [search order](../../apps/waddle_display/lib/config/dev_dotenv_secrets.dart) wins. Set **`OPENAI_API_KEY`** and/or **`WADDLE_JOKES_ACCESS_TOKEN`**. The file is [gitignored](../../.gitignore). **Release** and **profile** builds do not read `.env`; use **`Environment=`** in **systemd** (or your supervisor) for production keys.

2. **Production / profile**: export the same variable names in the process environment before launching `waddle_display`.

3. **Tests / fakes**: pass a `Map<String, String>` into `ProviderConfigResolver(db, env)`; see [`provider_config_resolver_test.dart`](../../packages/waddle_shared/test/config/provider_config_resolver_test.dart) and [`joke_data_provider_test.dart`](../../apps/waddle_display/test/data/joke_data_provider_test.dart). Use [`InMemorySecretStore`](../../packages/waddle_shared/lib/secrets/in_memory_secret_store.dart) only for **OAuth**-focused tests (Google / Microsoft Graph), not for jokes static keys.

4. **OAuth (Google / Microsoft)**: debug `.env` can still seed **`SecretStore`** via `applyGoogleTokensFromDevDotenv` / `applyMicrosoftGraphTokensFromDevDotenv` in [`main.dart`](../../apps/waddle_display/lib/main.dart). Headless Linux needs a working Secret Service for those flows.

Note: this env flow configures static provider API keys. Admin/install password authentication uses `waddle_api.key` from the app support directory, not an env variable.
