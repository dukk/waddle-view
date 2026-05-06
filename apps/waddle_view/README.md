# Waddle View

Flutter **Linux** TV dashboard (Windows desktop supported for local development). Features: **Drift** SQLite, filesystem **blob** store, **SecretStore**, sequential **data collection** engine, **curated bottom ticker** (RTL marquee), **RSS news slides** with an article-link **QR code** for scanning, **overlay alerts** (optional QR), embedded **Shelf** REST API with per-deployment API key.

For module boundaries, startup order, and **Mermaid** sequence diagrams (startup, data collection, REST alerts, ticker), see **[`ARCHITECTURE.md`](ARCHITECTURE.md)**.

## Prerequisites

- **Flutter** (stable channel), [`flutter doctor`](https://docs.flutter.dev/get-started/install) clean for your targets.
- **Windows dev**:
  - Visual Studio **2022** (Community or Build Tools) with the **Desktop development with C++** workload.
  - **C++ ATL** for the same MSVC toolset: Visual Studio Installer → **Modify** → **Individual components** → search **ATL** → enable **C++ ATL for latest v143 build tools (x86 & x64)** (wording may vary slightly by VS version). Required because [`flutter_secure_storage_windows`](https://pub.dev/packages/flutter_secure_storage) includes `atlstr.h`; without ATL, `flutter run -d windows` fails with **C1083 Cannot open include file: 'atlstr.h'**.
  - **Developer Mode** (Settings → System → For developers) so Windows allows **symlinks** used by Flutter plugins (`Building with plugins requires symlink support`).
- **Linux / Pi builds**: `flutter config --enable-linux-desktop` and distro packages aligned with [Flutter Linux desktop](https://docs.flutter.dev/platform-integration/linux/setup) (e.g. `clang`, `cmake`, `ninja-build`, `pkg-config`, **libgtk-3-dev**).

**Pexels video slides** use [`media_kit`](https://pub.dev/packages/media_kit) with bundled native libraries (`media_kit_libs_video`) so playback works on **Windows and Linux** desktop (the stock `video_player` plugin does not). Startup calls `MediaKit.ensureInitialized()` in `lib/main.dart`.

**Dependency note:** `webfeed` pins `xml` 5.x while `media_kit_video` pulls `xml` 6.x transitively. `pubspec.yaml` includes a **`dependency_overrides`** entry for `xml` so versions resolve; RSS parsing remains covered by tests.

### Troubleshooting (Windows)

| Symptom | What to do |
|--------|----------------|
| `Building with plugins requires symlink support` | Turn on **Developer Mode**, open a new terminal, run `flutter clean`, then build again. |
| `fatal error C1083: ... 'atlstr.h': No such file or directory` | Install the **C++ ATL** individual component (see above), restart the terminal, then `flutter clean` and `flutter run -d windows`. |
| `Failed to decode advisories ... advisoriesUpdated must be a String` during `flutter pub get` | Usually a **pub.dev / Dart SDK** mismatch; if dependencies still resolve (`Got dependencies!`), you can ignore it. If `pub get` aborts, run **`flutter upgrade`** so `dart` / `pub` match current pub.dev. |

## First-time setup

From this directory (`apps/waddle_view`):

```bash
flutter pub get
dart run build_runner build
```

After editing `lib/persistence/tables.dart` or `database.dart` schema:

```bash
dart run build_runner build
```

## Run locally (debug and other modes)

List devices, then pick one:

```bash
flutter devices
flutter run -d windows    # common on a Windows dev machine
flutter run -d linux      # Linux desktop or Pi with Flutter toolchain
```

`flutter run` defaults to **debug**: asserts, tracing, and **hot reload** (`r` in the terminal) / **hot restart** (`R`). In debug, the data collection engine uses a **shorter idle** between cycles than in profile or release (see `lib/main.dart`).

**Unhandled errors (release / kiosk):** most framework, async isolate, and root-zone failures are logged to **stderr** and the Dart **developer log** (name `Fatal.*`), then the process **restarts** by spawning the same executable with the same arguments (`lib/bootstrap/app_fatal_error_recovery.dart`). If restart fails, the process exits with a non-zero code so a supervisor (e.g. **systemd**) can start a fresh instance. Common **layout overflow** assertions (for example `RenderFlex overflowed`) are logged under **`Flutter.recoverable`** and **do not** trigger that restart so the dashboard keeps running. This does not apply to **flutter test** (tests do not run `main()`).

Useful variants:

| Command | When to use |
|--------|-------------|
| `flutter run` | Default **debug** session. |
| `flutter run --profile` | Near-release performance, still `flutter run` tooling (e.g. DevTools). |
| `flutter run --release` | Closest to what users get from `flutter build`; on **Linux**, release affects window chrome (e.g. maximize policy in `lib/window/startup_window_policy.dart`). |

## Quality checks (CI-aligned)

```bash
flutter analyze
flutter test --coverage
dart run tool/coverage_check.dart --min=90
```

Per-test wall time is capped at **60s** by `dart_test.yaml` (and CI uses the same `--timeout=60s`) so a stuck async test fails instead of blocking the suite. Override in code only when a test is genuinely slow: `test('...', () { ... }, timeout: Timeout(Duration(minutes: 2)));`

## Build installable bundles (local)

Release binaries are what you ship or copy to a device (no hot reload).

```bash
flutter build windows --release
flutter build linux --release
```

- **Windows**: runnable under `build/windows/x64/runner/Release/` (launch `waddle_view.exe` from Explorer or a terminal).
- **Linux**: bundle under `build/linux/<arch>/release/bundle/` (e.g. `arm64` on an ARM64 host). Run the `waddle_view` executable from that **bundle** directory so assets resolve correctly.

Tagged **Pi** tarballs and `install.sh` are produced in CI and documented under [`../../docs/pi/`](../../docs/pi/); templates live in [`../../deploy/linux-arm64/`](../../deploy/linux-arm64/).

## Deployed / Raspberry Pi (summary)

1. Obtain **`waddle-view-linux-arm64-<tag>.tar.gz`** (GitHub Releases or CI artifacts); verify **SHA256** when published.
2. On 64-bit Raspberry Pi OS, extract and run **`install.sh`** (installs under `/opt/waddle-view` by default, creates **`/etc/waddle-view/api.key`** for operator reference—see REST section below).
3. Start the app from **`/opt/waddle-view/bundle/waddle_view`** with a graphical session (`DISPLAY` set for systemd/kiosk). Optional: **`waddle-view.service`** in `deploy/linux-arm64/`, autostart `.desktop`, disable screen blanking for kiosk use.

Full steps, upgrades, and API examples: **[`docs/pi/using-the-image.md`](../../docs/pi/using-the-image.md)**, **[`docs/pi/upgrade.md`](../../docs/pi/upgrade.md)**, **[`docs/pi/api.md`](../../docs/pi/api.md)**.

## Local REST API and admin UI (debug, profile, release)

- Defaults to **`127.0.0.1:8787`**. Set `WADDLE_HTTP_BIND` (and optional `WADDLE_HTTP_PORT`) to expose on LAN.
- **Authentication**: `X-Api-Key` or `Authorization: Bearer <key>` (see `docs/pi/api.md`).
- **Key file used by the app**: **`waddle_api.key`** in Flutter’s **application support** directory for the user running the process (`getApplicationSupportDirectory()` in `lib/main.dart`). The file is created on first launch if missing. Use that file’s contents for `curl` and automation on the same machine as the app.
- **Install/admin password source**: same key file (`waddle_api.key`). There is no `.env` variable for this password in the current runtime.
- **`/v1/health`** does not require a key; other `/v1/*` routes return **503** if the key file is missing or empty, **401** if the key is wrong.
- **Admin UI**: open `/admin/login` on the same base URL. First login requires password change, which rotates `waddle_api.key`.

### Display theme (`config_key_values`)

- **Key**: `display.theme.id`
- **Values**: `navy_coral` (default), `graphite_amber`
- **Operator UI**: Admin home → Curator → **Display theme** (saved with other curator settings).
- **Code**: palettes and builders live under [`lib/theme/config/`](lib/theme/config/); registered ids are listed in [`lib/theme/config/display_theme_registry.dart`](lib/theme/config/display_theme_registry.dart).

### Screen program (main carousel)

When the app assembles a timed program from `screen_definitions`, [`ScreenProgramCurator`](lib/curator/screen_program_curator.dart) pre-assigns **content ids** on each [`ResolvedSlide`](lib/curator/screen_program_curator.dart) for **jokes**, **RSS articles**, **trivia** (and existing **random photo** pools). Slide widgets read those ids from `randomChoices` first, so the same joke or article is not shown twice in one program when SQLite has enough distinct rows. If every candidate is already used, the slide falls back to the previous random / “best article” selection. Multi-article RSS widgets use suffixed keys, for example **`main_rss_article_columns_0`** … **`_2`**, or **`main_rss_article_stack_0`** / **`_1`** for the two-row stack layout ([`rss_article_stack_slide_widget.dart`](lib/dashboard/rss_article_stack_slide_widget.dart)). The **`rss_article_columns`** layout places a **QR code** under each column’s **title** (start-aligned) with the **summary beside it** when that article’s `link` is non-empty; optional widget `config` **`qrLogicalSize`** (default **80**, clamped) scales the code after the viewport multiplier ([`rss_article_columns_slide_widget.dart`](lib/dashboard/rss_article_columns_slide_widget.dart)).

Each **`screen_definitions`** row stores runtime **`layout_json`** plus documentation columns **`layout_json_schema`** (JSON Schema for the layout document) and **`example_layout_json`** (sample payload). `GET /v1/screens` includes the schema and example fields.

- **RSS screen photos** — config key **`curator.news.screens.require_photo`** (default **true** in seed): when true, only RSS rows with a downloaded image are used for **screen** slides; the **ticker** is unchanged. If a news screen must still run (e.g. **min placements** / data-key minimum) and no image-backed article is available, the curator may place a photo-less row and set **`*_imageMode`** = **`icon`** (per slot for columns/stack) so the UI shows a **newspaper** icon instead of a photo.
- **Summary fit** — optional widget `config` on RSS layouts: **`summaryCapacityChars`** (single `rss_article`), **`summaryCapacityCharsPerColumn`** (`rss_article_columns`), **`summaryCapacityCharsPerSlot`** (`rss_article_stack`). The curator scores screen+article pairs so summary text length is less likely to be wasted or heavily truncated. Seeded default news screens set these in `layoutJson` ([`initial_seed.dart`](lib/seed/initial_seed.dart)).

### Text scale — screens vs ticker (`config_key_values`)

Separate semantic sizes for carousel content and the bottom marquee (each multiplied by the app’s TV base text scale and the platform accessibility scaler).

| Key | Purpose |
|-----|---------|
| `display.text_scale.screen` | Slides, alerts, admin-facing on-device UI under the main scaffold |
| `display.text_scale.ticker` | Bottom ticker / marquee strip |

**Values** (hyphenated in the database): `x-small`, `smaller`, `small`, `normal` (default), `large`, `larger`, `x-large`. Underscores and spacing are normalized on read/write.

**Operator UI**: Admin → Curator → **Screen text scale** and **Ticker text scale**.

**Code**: [`lib/theme/display_text_scale_kv.dart`](lib/theme/display_text_scale_kv.dart).

Startup logs include **`REST listening at …`** with the bound **base URL**. To show the same information on the TV carousel, enable the **`dev_local_api`** row in **`screen_definitions`** (`enabled = 1`); that developer slide shows the URL and an **`X-Api-Key` / `waddle_api.key`** reminder.

## Raspberry Pi / Linux runtime notes

- **GTK / libgtk-3** and typical Flutter Linux build deps (`clang`, `cmake`, `ninja-build`, `pkg-config`).
- **Secret storage**: `flutter_secure_storage` uses the Secret Service / **libsecret** where available; headless images without D-Bus may need a documented fallback (see repo **`docs/pi/`**).
- **Data**: SQLite and **`media/`** live under the application support directory (see `path_provider` on device).

The **`content_categories`** table holds shared category ids for **RSS** (`rss_feed_sources.category`), **Pexels** (`photos.category` / `videos.category`), **jokes** (`joke_categories.id`), and **trivia** (`trivia_categories.id`). Each row has a display **`label`**, optional **`material_icon_name`** (resolved in the app via [`content_category_material_icon.dart`](lib/dashboard/content_category_material_icon.dart)), and optional **`icon_blob_key`** for a custom image in the blob store. Initial rows are created by migration to schema version **19** and by [`ensureDefaultContentCategories`](lib/seed/content_category_seed.dart) during startup seeding.

## Provider secrets (OpenAI / jokes / trivia)

The joke and trivia data providers read OpenAI API keys from **SecretStore**, not from `provider_settings`.

- Jokes key: `provider:access_token:jokes`
- Trivia key: `provider:access_token:trivia`

**Local onboarding:** copy **[`.env.example`](.env.example)** to **`.env`** in this directory and set **`OPENAI_API_KEY`** (or **`WADDLE_JOKES_ACCESS_TOKEN`** / **`WADDLE_TRIVIA_ACCESS_TOKEN`**). In **debug** builds, the app loads that file and stores provider tokens automatically (see [`lib/config/dev_dotenv_secrets.dart`](lib/config/dev_dotenv_secrets.dart)). Full detail, monorepo paths, and fallbacks: **[`docs/pi/development.md`](../../docs/pi/development.md#joke-data-provider-openai-api-key)**.

## Pexels photos / videos provider

The **Pexels** provider (`id` / `provider_type`: **`pexels`**) downloads curated photos (`GET /v1/curated`) and popular videos (`GET /v1/videos/popular` with duration bounds), stores binaries in the **blob** store, and keeps metadata in **`photos`** and **`videos`** (with **`data_provider`** set to the provider id, e.g. **`pexels`**). API key: **`provider:access_token:pexels`** in **SecretStore** (never in SQLite).

**Debug `.env`:** **`PEXELS_API_KEY`** or **`WADDLE_PEXELS_ACCESS_TOKEN`** (see [`.env.example`](.env.example)).

**`provider_settings.config_json`** (JSON) holds the runtime payload. **`config_json_schema`** and **`example_config_json`** are documentation columns (JSON Schema and sample JSON) populated per row type.

**`config_json`** for Pexels supports:

- **`maxPhotos`** / **`maxVideos`**: retention cap (default 100); oldest rows are removed with their blobs.
- **`photosPerHour`** / **`videosPerHour`**: rolling 60-minute download caps (default 2 each).
- **`minVideoSeconds`** / **`maxVideoSeconds`**: inclusive duration window for videos (defaults **11** and **29** seconds).
- **`sources`**: optional list of `{ "query": "…", "category": "…" }` for `/v1/search` (photos) and `/v1/videos/search` (videos); results use that **category** string (the default curated/popular path uses category **`pexels`**).

**Screens:** widget types **`pexels_photo`** and **`pexels_video`** (single-widget layouts). Optional `config.categoryId` selects the curator pool (`pexels_photo` vs `pexels_photo:<category>`). Seed adds **`pexels_photo`** / **`pexels_video`** rows in **`screen_definitions`** disabled by default; enable after configuring the API key. Attribution (photographer name, profile URL, alt text) is shown on the photo slide; videos autoplay **muted** unless `config.unmuted` is true.

## Outlook calendar (Microsoft Graph)

The **Outlook calendar** provider (`id` / `provider_type`: **`outlook_calendar`**) reads delegated calendar data via [Microsoft Graph](https://learn.microsoft.com/en-us/graph/api/resources/calendar) `calendarView` and stores events in **`calendar_events`** (shown on the **`calendar_month`** slide). Seed adds the provider **disabled** by default; set **`provider_settings.enabled`** after configuration.

**App registration (Entra ID):** delegated permissions **`Calendars.Read`**, **`User.Read`**, and **`offline_access`**. The shared public **client id** lives in **`config_key_values`** as **`microsoft.graph.client_id`** (default `27bc410e-75a4-4bdc-9281-921f446aef52` on first seed). Other Graph-based providers should read the same key.

**Authentication platform:** turn on **Allow public client flows** (device code). Under **Authentication**, add a **Mobile and desktop applications** redirect URI **`https://login.microsoftonline.com/common/oauth2/nativeclient`** (same value the app sends as `redirect_uri` on token and device-code requests). Without this, Entra may return errors such as a missing **`redirect_uri`** on the request.

**SecretStore keys (per Microsoft account, not per provider row):**

- Access: **`provider:access_token:microsoft_graph:<graphAccountKey>`**
- Refresh: **`provider:refresh_token:microsoft_graph:<graphAccountKey>`**

**OAuth:** when access and refresh tokens are missing or expired, the provider starts the **device code** flow. A **`dashboard_alerts`** row shows the **user code** and verification URL on the dashboard, and a **QR code** (when the identity platform returns `verification_uri_complete`, otherwise the base verification URL) so you can open the sign-in page on a phone. Repeated prompts are throttled (per account) after the last device-code attempt.

**`provider_settings.config_json`** (JSON):

- **`accounts`**: list of `{ "graphAccountKey": "<id>", "sources": [ ... ] }`. Each **`graphAccountKey`** must match the suffix used in SecretStore (e.g. `personal`, `work`).
- **`sources`**: list of `{ "mailbox": "<upn-or-me>", "calendars": ["Calendar", …] }`. **`mailbox`** is the Graph user (`me` or a UPN). **`calendars`**: display names or Graph calendar ids; an **empty** list means the user’s **default** calendar only.
- **`pastDays`** / **`futureDays`**: inclusive window around **today’s UTC midnight** (defaults **14** / **14**).

**`provider_settings.poll_seconds`:** default **3600** (one sync per hour when enabled).

**Debug `.env`:** optional **`WADDLE_MSGRAPH_ACCESS_TOKEN_<graphAccountKey>`** and **`WADDLE_MSGRAPH_REFRESH_TOKEN_<graphAccountKey>`** (see [`.env.example`](.env.example)).

## Drift codegen

After editing `lib/persistence/tables.dart` or `database.dart` schema:

```bash
dart run build_runner build
```
