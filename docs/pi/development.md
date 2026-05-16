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
dart run build_runner build --delete-conflicting-outputs -C packages/waddle_shared
cd packages/waddle_shared
flutter test
cd ../..
```

## Agent rules

See [`AGENTS.md`](../../AGENTS.md) and [`.cursor/rules/waddle-view-flutter.mdc`](../../.cursor/rules/waddle-view-flutter.mdc).

## Secret storage on Linux

`flutter_secure_storage` expects **D-Bus** and a compatible **Secret Service** (e.g. gnome-keyring) for **Google Calendar** and **Microsoft Graph** OAuth token persistence. Minimal images may lack this; document a fallback for your deployment rather than storing those tokens in SQLite.

**Static provider API keys** (see [`apps/waddle_display/.env.example`](../../apps/waddle_display/.env.example) for names such as **`WADDLE_OPENAI_API_KEY`**, **`WADDLE_OPEN_WEATHER_MAP_API_KEY`**, **`WADDLE_PEXELS_API_KEY`**, **`WADDLE_FINHUB_API_KEY`**, **`WADDLE_FLICKR_API_KEY`**) are **not** stored in `SecretStore`; they are read from **environment variables** merged at startup (`Platform.environment` plus debug `.env` — see [`mergeBootstrapEnv`](../../apps/waddle_display/lib/config/dev_dotenv_secrets.dart) and [`provider_access_token_env.dart`](../../packages/waddle_shared/lib/config/provider_access_token_env.dart)).

## Joke data provider (OpenAI API key)

The joke collector ([`JokeDataProvider`](../../packages/waddle_data_providers/lib/joke_openai/joke_data_provider.dart)) calls the OpenAI HTTP API using a bearer token. Tokens **must not** live in SQLite ([`AGENTS.md`](../../AGENTS.md)). At runtime, [`ProviderConfigResolver`](../../packages/waddle_shared/lib/config/provider_config_resolver.dart) fills `ProviderRuntimeConfig.accessToken` from the merged **env map** (not from `SecretStore`).

| What | Value |
|------|--------|
| Provider id (also `integrations.id`) | `joke_openai` (see [`kJokeProviderId`](../../packages/waddle_data_providers/lib/joke_openai/joke_data_provider.dart)) |
| Env resolution | [`resolveProviderAccessTokenFromEnv`](../../packages/waddle_shared/lib/config/provider_access_token_env.dart) for static keys (e.g. **`WADDLE_OPENAI_API_KEY`** for `joke_openai` / legacy `jokes`, trivia, and OpenTDB-backed trivia ids) |
| Non-secret config | `integrations` row for `joke_openai`: `base_url` (optional override; default API root is defined on the provider), `config_json` for model and prompts — see seed and [`JokeProviderExtraConfig`](../../packages/waddle_data_providers/lib/joke_openai/joke_provider_extra_config.dart) |

If no token is resolved (null or empty), [`collect`](../../packages/waddle_data_providers/lib/joke_openai/joke_data_provider.dart) exits early and logs that the API token is missing.

### How to set the key as a developer

The UI does not expose a form for static provider API keys. Recommended onboarding paths:

1. **`.env` file (debug)** — In **debug** desktop/server builds only (not web), the app loads a dotenv file from disk and merges it into the env map used by [`ProviderConfigResolver`](../../packages/waddle_shared/lib/config/provider_config_resolver.dart). Copy **[`apps/waddle_display/.env.example`](../../apps/waddle_display/.env.example)** to **`.env`** or **`.env.development`** in `apps/waddle_display/` (or add `assets/.env` / `assets/.env.development` in the same app directory). The first existing file in the [search order](../../apps/waddle_display/lib/config/dev_dotenv_secrets.dart) wins. Set **`WADDLE_OPENAI_API_KEY`** (and other `WADDLE_*` keys per provider). The file is [gitignored](../../.gitignore). **Release** and **profile** builds do not read `.env`; use **`Environment=`** in **systemd** (or your supervisor) for production keys.

2. **Production / profile**: export the same variable names in the process environment before launching `waddle_display`.

3. **Tests / fakes**: pass a `Map<String, String>` into `ProviderConfigResolver(db, env)`; see [`provider_config_resolver_test.dart`](../../packages/waddle_shared/test/config/provider_config_resolver_test.dart) and [`joke_data_provider_test.dart`](../../apps/waddle_display/test/data/joke_data_provider_test.dart). Use [`InMemorySecretStore`](../../packages/waddle_shared/lib/secrets/in_memory_secret_store.dart) only for **OAuth**-focused tests (Google / Microsoft Graph), not for jokes static keys.

4. **OAuth (Google / Microsoft)**: access and refresh tokens live in **`SecretStore`** only (device-code sign-in in the app, or `waddlectl secrets set` on Linux). Public OAuth **client ids** use **`WADDLE_GOOGLE_CLIENT_ID`** and **`WADDLE_MICROSOFT_GRAPH_CLIENT_ID`** in the process environment (or merged debug `.env`) — not SQLite. Headless Linux needs a working Secret Service for token persistence.

Note: this env flow configures static provider API keys. Operator REST authentication uses session tokens from **`POST /v1/auth/login`** (bootstrap user **`display`** / password = contents of **`waddle_instance.id`** in app support until the first named user is created). Legacy **`waddle_api.key`** is renamed to **`waddle_instance.id`** on upgrade.
