# Developing Waddle View

## Mono-repo layout

- Application root: **`apps/waddle-display/`**
- Pi / ops docs: **`docs/pi/`**
- Install templates: **`deploy/linux-arm64/`**

## Pi / Linux ARM64 release (CI)

The **[`release-pi.yml`](../../.github/workflows/release-pi.yml)** job runs on **`ubuntu-22.04-arm`** so the Linux ARM64 binary stays compatible with **Raspberry Pi OS Bookworm** (glibc **2.36**). Do not switch that runner to Ubuntu 24.04 without also moving the supported Pi base image to a newer distro.

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

## Joke data provider (OpenAI API key)

The joke collector ([`JokeDataProvider`](../../apps/waddle-display/lib/data/providers/joke/joke_data_provider.dart)) calls the OpenAI HTTP API using a bearer token. Tokens **must not** live in SQLite ([`AGENTS.md`](../../AGENTS.md)); they are merged at runtime by [`ProviderConfigResolver`](../../apps/waddle-display/lib/config/provider_config_resolver.dart) from the app’s [`SecretStore`](../../apps/waddle-display/lib/secrets/secret_store.dart) (in production this is [`FlutterSecureSecretStore`](../../apps/waddle-display/lib/secrets/flutter_secure_secret_store.dart)).

| What | Value |
|------|--------|
| Provider id (also `provider_settings.id`) | `jokes` (see [`kJokeProviderId`](../../apps/waddle-display/lib/data/providers/joke/joke_data_provider.dart)) |
| Secret key string | `provider:access_token:jokes` (prefix [`ProviderConfigResolver.accessTokenKey`](../../apps/waddle-display/lib/config/provider_config_resolver.dart) + `:` + provider id) |
| Secret value | Your OpenAI API key (for example `sk-…`) |
| Non-secret config | `provider_settings` row for `jokes`: `base_url` (optional override; default API root is defined on the provider), `config_json` for model and prompts — see seed and [`JokeProviderExtraConfig`](../../apps/waddle-display/lib/data/providers/joke/joke_provider_extra_config.dart) |

If no token is stored (null or empty), [`collect`](../../apps/waddle-display/lib/data/providers/joke/joke_data_provider.dart) exits early and logs that the API token is missing.

### How to set the key as a developer

The UI does not yet expose a form for provider tokens. Recommended onboarding paths:

1. **`.env` file (recommended)** — In [**debug**](../../apps/waddle-display/lib/config/dev_dotenv_secrets.dart) desktop/server builds only (not web), the app loads a dotenv file from disk and writes the token into [`SecretStore`](../../apps/waddle-display/lib/secrets/secret_store.dart) on startup. Copy [`dotenv.example`](../../apps/waddle-display/dotenv.example) to **`.env`** or **`.env.development`** in `apps/waddle-display/` (or add `assets/.env` / `assets/.env.development` in the same app directory). The first existing file in the [search order](../../apps/waddle-display/lib/config/dev_dotenv_secrets.dart) wins (`.env` before `.env.development`). Set either:
   - **`OPENAI_API_KEY`** — usual OpenAI key name, or
   - **`WADDLE_JOKES_ACCESS_TOKEN`** — if you need a different value than any global `OPENAI_API_KEY` in the same file.  
   The file is [gitignored](../../.gitignore) (do not commit real keys). The app also looks for `apps/waddle-display/.env` when your shell’s current directory is the **monorepo root** (e.g. some IDE / `flutter run` setups). **Release** and **profile** builds do not read `.env` for this path.

2. **One-off code** (fallback): call `SecretStore.write('provider:access_token:jokes', '<your-api-key>')` once using the same storage backend the app uses (for example a **temporary** debug-only call right after the store is created in [`main.dart`](../../apps/waddle-display/lib/main.dart)), run the app so the value is persisted, then **remove** that code so the secret is never committed.

3. **Tests / fakes**: use [`InMemorySecretStore`](../../apps/waddle-display/lib/secrets/in_memory_secret_store.dart) and the same key; see [`provider_config_resolver_test.dart`](../../apps/waddle-display/test/provider_config_resolver_test.dart) and [`joke_data_provider_test.dart`](../../apps/waddle-display/test/data/joke_data_provider_test.dart).

4. **Platform notes**: On Windows and Linux desktop, `flutter_secure_storage` persists secrets using the platform integration for that OS (see package docs). Headless Linux still needs a working Secret Service if you rely on this store; otherwise plan a deployment-specific way to populate secrets without putting them in SQLite.

Note: this dotenv flow configures provider API tokens only. Admin/install password authentication uses `waddle_api.key` from the app support directory, not an env variable.
