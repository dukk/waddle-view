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

From this directory (`apps/waddle-display`):

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

- **Windows**: runnable under `build/windows/x64/runner/Release/` (launch `waddle_display.exe` from Explorer or a terminal).
- **Linux**: bundle under `build/linux/<arch>/release/bundle/` (e.g. `arm64` on an ARM64 host). Run the `waddle_display` executable from that **bundle** directory so assets resolve correctly.

Tagged **Pi** tarballs and `install.sh` are produced in CI and documented under [`../../docs/pi/`](../../docs/pi/); templates live in [`../../deploy/linux-arm64/`](../../deploy/linux-arm64/).

## Deployed / Raspberry Pi (summary)

1. Obtain **`waddle-view-linux-arm64-<tag>.tar.gz`** (GitHub Releases or CI artifacts); verify **SHA256** when published.
2. On 64-bit Raspberry Pi OS, extract and run **`install.sh`** (installs under `/opt/waddle-view` by default, creates **`/etc/waddle-view/api.key`** for operator reference—see REST section below).
3. Start the app from **`/opt/waddle-view/bundle/waddle_display`** with a graphical session (`DISPLAY` set for systemd/kiosk). Optional: **`waddle-view.service`** in `deploy/linux-arm64/`, autostart `.desktop`, disable screen blanking for kiosk use.

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
- **Default palette details** (`navy_coral`): primary starts at `#0D1B2A` and follows an 8-color sequence ending with 3 accents (`#E05C6C`, `#FFE356`, `#966CB3`). The theme also exposes a `PaletteTertiaryLayers` extension with 4 tertiary layers for each palette color, plus gradients for the first pair (`#0D1B2A` → `#1B263B`) and next pair (`#415A77` → `#778DA9`).
- **Icon color**: the default icon color is `dustyDenim` (`#778DA9`) via theme `IconThemeData` and `PaletteTertiaryLayers.iconColor`. Multi-icon screens may use accent colors for emphasis (for example, current weather icon) while secondary icons keep the standard icon color.

### Screen program (main carousel)

When the app assembles a timed program from `screen_definitions`, [`ScreenProgramCurator`](lib/curator/screen_program_curator.dart) pre-assigns **content ids** on each [`ResolvedSlide`](lib/curator/screen_program_curator.dart) for **jokes**, **RSS articles**, **trivia** (and existing **random photo** pools). Slide widgets read those ids from `randomChoices` first, so the same joke or article is not shown twice in one program when SQLite has enough distinct rows. If every candidate is already used, the slide falls back to the previous random / “best article” selection. Multi-article RSS widgets use suffixed keys, for example **`main_rss_article_columns_0`** … **`_2`**, or **`main_rss_article_stack_0`** / **`_1`** for the two-row stack layout ([`rss_article_stack_slide_widget.dart`](lib/display/screens/rss_article/rss_article_stack_slide_widget.dart)). The **`rss_article_columns`** layout places a **QR code** under each column’s **title** (start-aligned) with the **summary beside it** when that article’s `link` is non-empty; optional widget `config` **`qrLogicalSize`** (default **80**, clamped) scales the code after the viewport multiplier ([`rss_article_columns_slide_widget.dart`](lib/display/screens/rss_article/rss_article_columns_slide_widget.dart)).

RSS widget `config` may include **`feedId`** (single feed), **`categoryId`** (slug shared with **`content_categories.id`**, pool key **`rss_category:<id>`**), or neither. With the global **`rss`** pool, the curator assigns articles from **one** category per slide so columns/stack rows do not mix unrelated feeds; it stores that id in **`randomChoices`** under **`rss_screen_category_id`** ([`ScreenProgramCurator.rssScreenCategoryChoiceKey`](lib/curator/screen_program_curator.dart)). **RSS**, **joke**, and **trivia** slides render a **category strip** at the top (label + icon from **`content_categories`**, with fallbacks — [`content_category_slide_header.dart`](lib/display/content_category_slide_header.dart)).

Each **`screen_definitions`** row stores runtime **`layout_json`** plus documentation columns **`layout_json_schema`** (JSON Schema for the layout document) and **`example_layout_json`** (sample payload). `GET /v1/screens` includes the schema and example fields.

- **Analog clock labels** — optional `analog_clock` widget `config.dialLabels` controls clock-face labels: **`none`** (default), **`numbers`** (1-12), **`roman`** (I-XII), or **`cardinal_numbers`** (12/3/6/9 only).
- **Analog clock hand accents** — by default, hands use accent colors **1/2/3** for **hour/minute/second**. Optional per-hand config keys can override accent choice: **`hourHandAccent`**, **`minuteHandAccent`**, **`secondHandAccent`** with values **`accent1`**, **`accent2`**, **`accent3`** (or numeric **`1`**, **`2`**, **`3`**).
- **RSS screen photos** — config key **`curator.news.screens.require_photo`** (default **true** in seed): when true, only RSS rows with a downloaded image are used for **screen** slides; the **ticker** is unchanged. If a news screen must still run (e.g. **min placements** / data-key minimum) and no image-backed article is available, the curator may place a photo-less row and set **`*_imageMode`** = **`icon`** (per slot for columns/stack) so the UI shows a **newspaper** icon instead of a photo.
- **Summary fit** — optional widget `config` on RSS layouts: **`summaryCapacityChars`** (single `rss_article`), **`summaryCapacityCharsPerColumn`** (`rss_article_columns`), **`summaryCapacityCharsPerSlot`** (`rss_article_stack`). The curator scores screen+article pairs so summary text length is less likely to be wasted or heavily truncated. Seeded default news screens set these in `layoutJson` ([`initial_seed.dart`](lib/seed/initial_seed.dart)).

### Bottom ticker (`ticker_definitions`)

SQLite table **`ticker_definitions`** configures the bottom marquee: which **types** run (`time`, `weather`, `news`, `quote`, `stocks`, `custom`), **order** (`sort_order`, then id), **`enabled`**, and **`frequency_weight`** (repeat that type’s item bundle that many times when building the curated list; identical bodies are still deduplicated). **`custom`** rows may set **`config_key`** to pin one `ticker.marquee.*` key; when null, every extra `ticker.marquee.*` key outside the standard weather/news/quote keys is included (legacy “extras” bucket).

Content still comes from **`config_key_values`** (`ticker.marquee.*`), live weather, stored RSS articles for **`news`**, and (for definition-based curation) enabled **`stock_symbols`** / **`stock_quotes`** when a **`stocks`** row is enabled. If **`ticker_definitions`** has **no rows** (empty table), curation keeps the legacy fixed order: time, standard keys, sorted extras — **without** stock lines. If the table has rows but **none are enabled**, curation falls back to **time** only.

Seeded defaults: **`ticker_time`** … **`ticker_stocks`** enabled, **`ticker_custom`** disabled ([`initial_seed.dart`](lib/seed/initial_seed.dart)).

### Text scale — screens vs ticker (`config_key_values`)

Separate semantic sizes for carousel content and the bottom marquee (each multiplied by the app’s TV base text scale and the platform accessibility scaler).

| Key | Purpose |
|-----|---------|
| `display.text_scale.screen` | Slides, alerts, admin-facing on-device UI under the main scaffold |
| `display.text_scale.ticker` | Bottom ticker / marquee strip |
| `display.alert.severity_icons` | JSON map: severity (`info`, `auth`, `warning`, `error`, `critical`, or custom) → Material icon name (underscore form; many names match [`content_category_material_icon.dart`](lib/display/content_category_material_icon.dart)). Merged with defaults; seeded on first run. |

**Values** (hyphenated in the database): `xxx-small`, `xx-small`, `x-small`, `smaller`, `small`, `normal` (default), `large`, `larger`, `x-large`, `xx-large`, `xxx-large`. Underscores and spacing are normalized on read/write.

**Operator UI**: Admin → Curator → **Screen text scale** and **Ticker text scale**.

**Code**: [`lib/theme/display_text_scale_kv.dart`](lib/theme/display_text_scale_kv.dart).

### Keyboard — overlay alerts

When an alert overlay is visible, **Enter** or **numpad Enter** dismisses the current (highest-priority) alert. If the alert has an expiry time (`expires_at`), a countdown bar at the bottom of the dialog (same visual language as the joke punchline timer) shrinks until the alert is hidden automatically.

### Keyboard screen history navigation

While the dashboard is focused, keyboard arrows can be used to browse curated programs:

- `Right`: move to the next screen in the current program. At the tail of the newest program, navigation stops and waits for a newly curated program.
- `Left`: move backward through the current program and then into older programs in history.
- On manual navigation, a timeline overlay appears at the bottom of the screen area (above ticker) and highlights the current screen by `screen_definitions.id`.
- At the oldest history boundary, the overlay shows an end-of-history message.
- If no arrow key is pressed for a few seconds, overlays fade out and automatic dwell-based rotation resumes.

Startup logs include **`REST listening at …`** with the bound **base URL**. To show the same information on the TV carousel, enable the **`dev_local_api`** row in **`screen_definitions`** (`enabled = 1`); that developer slide shows the URL and an **`X-Api-Key` / `waddle_api.key`** reminder.

## Raspberry Pi / Linux runtime notes

- **GTK / libgtk-3** and typical Flutter Linux build deps (`clang`, `cmake`, `ninja-build`, `pkg-config`).
- **Secret storage**: `flutter_secure_storage` uses the Secret Service / **libsecret** where available; headless images without D-Bus may need a documented fallback (see repo **`docs/pi/`**).
- **Data**: SQLite and **`media/`** live under the application support directory (see `path_provider` on device).

The **`content_categories`** table holds shared category ids for **RSS** (`rss_feed_sources.category`), **Pexels** (`photos.category` / `videos.category`), **jokes** (`joke_categories.id`), and **trivia** (`trivia_categories.id`). Each row has a display **`label`**, optional **`material_icon_name`** (resolved in the app via [`content_category_material_icon.dart`](lib/display/content_category_material_icon.dart)), and optional **`icon_blob_key`** for a custom image in the blob store. Initial rows are created by migration to schema version **19** and by [`ensureDefaultContentCategories`](lib/seed/content_category_seed.dart) during startup seeding.

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

**Screens:** widget types **`pexels_photo`**, **`pexels_photo_collage`** (multi-tile layouts; `config.template` picks one of the built-in grids, and the curator matches **native aspect ratio** to each cell when **`blob_metadata.pixel_width` / `pixel_height`** are populated), and **`pexels_video`**. Optional `config.categoryId` selects the curator pool (`pexels_photo` vs `pexels_photo:<category>`). Seed adds **`pexels_photo`**, several collage screens, and **`pexels_video`** rows in **`screen_definitions`** disabled by default; enable after configuring the API key. Attribution (photographer name, profile URL, alt text) is shown on the photo slide; videos autoplay **muted** unless `config.unmuted` is true.

## Stock quote provider (Finnhub)

The **stocks** provider (`id` / `provider_type`: **`stocks`**) calls [Finnhub](https://finnhub.io/docs/api/quote) **`GET /api/v1/quote?symbol=...&token=...`** for every enabled row in **`stock_symbols`** and upserts the latest quote into **`stock_quotes`** (one row per symbol). API key: **`provider:access_token:stocks`** in **SecretStore** (never in SQLite).

**Debug `.env`:** **`FINNHUB_API_KEY`** or **`WADDLE_STOCKS_ACCESS_TOKEN`** (see [`.env.example`](.env.example)).

**Symbol management:** seed inserts AAPL / MSFT / GOOG / NVDA / AMZN with **AAPL** and **MSFT** enabled by default; toggle [`StockSymbols.enabled`](lib/persistence/tables.dart) to add or remove symbols at runtime. When `stock_symbols` has no enabled rows the provider falls back to **`config_json.defaultSymbols`** and writes those entries into the table on first collect so the slide widget can display them.

**`config_json`** for stocks supports:

- **`maxSymbolsPerCollect`**: ceiling on quote requests per tick (default **25**).
- **`defaultSymbols`**: list of `{ "symbol": "...", "displayName": "..." }` entries used when `stock_symbols` is empty.

**Schema:** **`stock_symbols(id, symbol, display_name, enabled)`** and **`stock_quotes(symbol_id, current_price, change_amount, percent_change, high_of_day, low_of_day, open_price, previous_close, quoted_at_ms, observed_at_ms)`** are added in schema version **21**.

**Screen:** widget type **`stock_quotes`**. Seed adds a **`stock_quotes`** row in **`screen_definitions`** disabled by default; enable after configuring the API key. The slide renders symbol, price, and percent change with up/down trend coloring per enabled symbol.

## Outlook calendar (Microsoft Graph)

The **Outlook calendar** provider (`id` / `provider_type`: **`outlook_calendar`**) reads delegated calendar data via [Microsoft Graph](https://learn.microsoft.com/en-us/graph/api/resources/calendar) `calendarView` and stores events in **`calendar_events`** (shown on the **`calendar_month`** slide). Seed adds the provider **disabled** by default; set **`provider_settings.enabled`** after configuration.

**App registration (Entra ID):** delegated permissions **`Calendars.Read`**, **`Files.Read`** (for OneDrive media sync), **`User.Read`**, and **`offline_access`**. The shared public **client id** lives in **`config_key_values`** as **`microsoft.graph.client_id`** (default `27bc410e-75a4-4bdc-9281-921f446aef52` on first seed). Other Graph-based providers should read the same key. If you already signed in before **`Files.Read`** was added, the next token refresh may fall back to **device code** once so you can re-consent for the broader scope.

**Authentication platform:** turn on **Allow public client flows** (device code). Under **Authentication**, add a **Mobile and desktop applications** redirect URI **`https://login.microsoftonline.com/common/oauth2/nativeclient`** (same value the app sends as `redirect_uri` on token and device-code requests). Without this, Entra may return errors such as a missing **`redirect_uri`** on the request.

**SecretStore keys (per Microsoft account, not per provider row):**

- Access: **`provider:access_token:microsoft_graph:<graphAccountKey>`**
- Refresh: **`provider:refresh_token:microsoft_graph:<graphAccountKey>`**

**OAuth:** when access and refresh tokens are missing or expired, the provider starts the **device code** flow. A **`dashboard_alerts`** row shows the **user code** and verification URL on the dashboard, and a **QR code** (when the identity platform returns `verification_uri_complete`, otherwise the base verification URL) so you can open the sign-in page on a phone. Repeated prompts are throttled (per account) after the last device-code attempt.

**`provider_settings.config_json`** (JSON):

- **`accounts`**: list of `{ "graphAccountKey": "<id>", "sources": [ ... ] }`. Each **`graphAccountKey`** must match the suffix used in SecretStore (e.g. `personal`, `work`).
- **`sources`**: list of mailbox objects. **`mailbox`** is the Graph user (`me` or a UPN). **`calendars`**: display names or Graph calendar ids, each either a **string** or `{ "calendar": "Name", "categoryId": "<content_categories.id>" }` to force a **content category** for every event from that calendar. An **empty** `calendars` array means the user’s **default** calendar only; optional **`defaultCategoryId`** then applies to those events. Optional **`categoryMap`** maps **Outlook** event category labels (Graph `categories`) to **`content_categories.id`** when no per-calendar override applies.
- **`pastDays`** / **`futureDays`**: inclusive window around **today’s UTC midnight** (defaults **14** / **14**).

**`calendar_events`** (schema **22+**) also stores **`ical_uid`** (for deduplication across calendars) and optional **`category_id`** (FK to **`content_categories`**). The **`calendar_month`** slide shows a category **icon** when present, **deduplicates** shared meetings, and **reuses** one time label for events at the same clock time or for **all-day** items on the same day. **Widget `config`** (optional): **`upcomingTime12Hour`** (default **true**) for `h:mm AM/PM` vs 24-hour; **`upcomingTimeNoonLabel`** (default **`Noon`**) for exactly 12:00 PM local; **`upcomingTimeWidthCompact`** / **`upcomingTimeWidth`** (default **88** / **104** logical px before TV scale) for the upcoming-events time column.

**`provider_settings.poll_seconds`:** default **3600** (one sync per hour when enabled).

**Debug `.env`:** optional **`WADDLE_MSGRAPH_ACCESS_TOKEN_<graphAccountKey>`** and **`WADDLE_MSGRAPH_REFRESH_TOKEN_<graphAccountKey>`** (see [`.env.example`](.env.example)).

## Google Calendar

The **Google Calendar** provider (`id` / `provider_type`: **`google_calendar`**) reads calendars/events from [Google Calendar API](https://developers.google.com/calendar/api/v3/reference) and stores normalized rows in **`calendar_events`** for the **`calendar_month`** slide.

Seed adds the provider **disabled** by default. Configure and enable in `provider_settings` when ready.

**OAuth client id:** set **`google.client_id`** in **`config_key_values`** to your Google OAuth client id.

**SecretStore keys (per Google account):**

- Access: **`provider:access_token:google:<googleAccountKey>`**
- Refresh: **`provider:refresh_token:google:<googleAccountKey>`**

**OAuth:** when cached access/refresh tokens are unavailable or expired, the provider starts OAuth **device authorization**. A `dashboard_alerts` row shows the user code and verification URL so an operator can approve access on another device.

**`provider_settings.config_json`** (JSON):

- **`accounts`**: list of `{ "googleAccountKey": "<id>", "sources": [ ... ] }`. Each `googleAccountKey` must match SecretStore key suffixes.
- **`sources`**: list of `{ "calendars": [ ... ], "defaultCategoryId": "<optional>" }`. Each calendar entry is a **string** or `{ "calendar": "primary", "categoryId": "<slug>" }`. Empty `calendars` defaults to **`primary`** for that account; **`defaultCategoryId`** applies when using that default or as a fallback for entries without their own **`categoryId`**.
- **`pastDays`** / **`futureDays`**: sync window around today’s UTC midnight (defaults **14** / **14**).

**`provider_settings.poll_seconds`:** default **3600**.

**Debug `.env`:** optional **`WADDLE_GOOGLE_ACCESS_TOKEN_<googleAccountKey>`** and **`WADDLE_GOOGLE_REFRESH_TOKEN_<googleAccountKey>`** (see [`.env.example`](.env.example)).

## OneDrive media (Microsoft Graph)

The **OneDrive media** provider (`id` / `provider_type`: **`onedrive_media`**) lists files in folders on the signed-in user’s **personal OneDrive** (`/me/drive/...`), downloads supported images and videos, and stores them in **`photos`** / **`videos`** with **`data_provider`** = **`onedrive_media`**. It reuses the same **SecretStore** keys and **device-code** flow as Outlook (**`provider:access_token:microsoft_graph:<graphAccountKey>`** / **`provider:refresh_token:...`**). Seed adds the row **disabled** by default.

**`provider_settings.config_json`** (JSON):

- **`accounts`**: list of `{ "graphAccountKey": "<id>", "sources": [ ... ] }` (same account keys as Outlook).
- **`sources`**: list of `{ "path": "/Pictures/MyFolder", "kind": "photo" | "video", "category": "<slug>", "maxFiles": <n>, "perPollLimit": <optional> }`. **`path`** is root-relative (leading `/` optional). **`category`** must match a **`content_categories.id`** (and optional **`config.categoryId`** on **`pexels_photo`** / **`pexels_video`** screens). **`maxFiles`**: retention cap per table (`photos` or `videos`) for that category—oldest OneDrive-sourced rows are removed with their blobs. **`perPollLimit`**: max **new** downloads per collect for that folder; omit to use **`maxFiles`**. **`globalPerPollLimit`**: cap on new downloads per engine cycle across all sources (default **50**).

**MIME types:** photos **`image/jpeg`**, **`image/png`**, **`image/webp`**, **`image/gif`**; videos **`video/mp4`**, **`video/quicktime`**.

**Screens:** use existing **`pexels_photo`** / **`pexels_video`** widgets; set **`config.categoryId`** to the same slug as the folder’s **`category`** so the curator pool includes OneDrive items alongside Pexels (or use a dedicated category for OneDrive-only folders).

**`provider_settings.poll_seconds`:** default **3600** when seeded.

## Drift codegen

After editing `lib/persistence/tables.dart` or `database.dart` schema:

```bash
dart run build_runner build
```
