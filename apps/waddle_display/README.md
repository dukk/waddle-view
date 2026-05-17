# Waddle View

Flutter **Linux** TV dashboard (Windows desktop supported for local development). Features: **Drift** SQLite, filesystem **blob** store, **environment-backed API keys** plus **`SecretStore`** for Google/Microsoft OAuth tokens only, sequential **data collection** engine, curated **bottom ticker** (RTL marquee), **RSS news slides** with an article-link **QR code** for scanning, **overlay alerts** (optional QR), configurable **festive display overlays** (hearts + short phrases driven from SQLite and theme accent colors), embedded **Shelf** REST API with per-deployment API key.

For module boundaries, startup order, and **Mermaid** sequence diagrams (startup, data collection, REST alerts, ticker), see **[`ARCHITECTURE.md`](ARCHITECTURE.md)**.

## Prerequisites

- **Flutter** (stable channel), [`flutter doctor`](https://docs.flutter.dev/get-started/install) clean for your targets.
- **Windows dev**:
  - Visual Studio **2022** (Community or Build Tools) with the **Desktop development with C++** workload.
  - **C++ ATL** for the same MSVC toolset: Visual Studio Installer → **Modify** → **Individual components** → search **ATL** → enable **C++ ATL for latest v143 build tools (x86 & x64)** (wording may vary slightly by VS version). Required because [`flutter_secure_storage_windows`](https://pub.dev/packages/flutter_secure_storage) includes `atlstr.h`; without ATL, `flutter run -d windows` fails with **C1083 Cannot open include file: 'atlstr.h'**.
  - **Developer Mode** (Settings → System → For developers) so Windows allows **symlinks** used by Flutter plugins (`Building with plugins requires symlink support`).
- **Linux / Pi builds**: `flutter config --enable-linux-desktop` and distro packages aligned with [Flutter Linux desktop](https://docs.flutter.dev/platform-integration/linux/setup) (e.g. `clang`, `cmake`, `ninja-build`, `pkg-config`, **libgtk-3-dev**).

**Pexels video slides** use [`media_kit`](https://pub.dev/packages/media_kit) with bundled native libraries (`media_kit_libs_video`) so playback works on **Windows and Linux** desktop (the stock `video_player` plugin does not). Startup calls `MediaKit.ensureInitialized()` in `lib/main.dart`.

**Dependency note:** `webfeed` pins `xml` 5.x while `media_kit_video` pulls `xml` 6.x transitively. The **workspace root** `pubspec.yaml` includes a **`dependency_overrides`** entry for `xml` so versions resolve; RSS parsing remains covered by tests.

### Troubleshooting (Windows)

| Symptom | What to do |
|--------|----------------|
| `Building with plugins requires symlink support` | Turn on **Developer Mode**, open a new terminal, run `flutter clean`, then build again. |
| `fatal error C1083: ... 'atlstr.h': No such file or directory` | Install the **C++ ATL** individual component (see above), restart the terminal, then `flutter clean` and `flutter run -d windows`. |
| `Failed to decode advisories ... advisoriesUpdated must be a String` during `flutter pub get` | Usually a **pub.dev / Dart SDK** mismatch; if dependencies still resolve (`Got dependencies!`), you can ignore it. If `pub get` aborts, run **`flutter upgrade`** so `dart` / `pub` match current pub.dev. |

## First-time setup

From the **repository root** (monorepo Pub workspace):

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs -C packages/waddle_shared
flutter test -C packages/waddle_shared
```

After editing `packages/waddle_shared/lib/persistence/tables.dart` or `database.dart` schema:

```bash
dart run build_runner build --delete-conflicting-outputs -C packages/waddle_shared
flutter test -C packages/waddle_shared
```

## Run locally (debug and other modes)

List devices, then pick one:

```bash
flutter devices
flutter run -d windows    # common on a Windows dev machine
flutter run -d linux      # Linux desktop or Pi with Flutter toolchain
```

`flutter run` defaults to **debug**: asserts, tracing, and **hot reload** (`r` in the terminal) / **hot restart** (`R`). In debug, the data collection engine uses a **shorter idle** between cycles than in profile or release (see `lib/main.dart`). Each debug session also creates a **timestamped console log file** under the app support directory: `debug_console_logs/debug_console_<UTC>.log` (see `lib/debug/debug_console_disk_logger.dart`). It captures `print` output, `debugPrint`, `AppDebugLog` lines from `lib/debug/app_debug_log.dart`, and fatal / recoverable Flutter error summaries written through the global handlers.

**Unhandled errors (release display):** most framework, async isolate, and root-zone failures are logged to **stderr** and the Dart **developer log** (name `Fatal.*`), then the process **restarts** by spawning the same executable with the same arguments (`lib/bootstrap/app_fatal_error_recovery.dart`). If restart fails, the process exits with a non-zero code so a supervisor (e.g. **systemd**) can start a fresh instance. Common **layout overflow** assertions (for example `RenderFlex overflowed`) are logged under **`Flutter.recoverable`** and **do not** trigger that restart so the dashboard keeps running. This does not apply to **flutter test** (tests do not run `main()`).

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
dart run tool/coverage_check.dart --min=85 --target=90
```

**Coverage gate:** **≥ 85%** is the CI **minimum** (build fails below it). **90%** is the **target**; between 85% and 90% the check **passes** but prints a **stderr warning** so coverage can be raised over time.

Per-test wall time is capped at **60s** by `dart_test.yaml` (and CI uses the same `--timeout=60s`) so a stuck async test fails instead of blocking the suite. Override in code only when a test is genuinely slow: `test('...', () { ... }, timeout: Timeout(Duration(minutes: 2)));`

## Operator CLI (`waddlectl`)

The **`apps/waddlectl`** package is a shell tool against the same **SQLite** database as the display app. Use **`backup create`** for a single-file archive of the database and **`media/`** blobs; it is **not** a substitute for backing up the whole machine.

**Prebuilt `waddlectl`** is included in **GitHub Release** artifacts next to the display app: **Windows** (`…/waddlectl/bin/waddlectl.exe` inside the `.zip` Release tree), **Linux** (`…/bundle/waddlectl/bin/waddlectl` next to `waddle_display` in the tarball’s `bundle/`). From a dev checkout you can build the same layout with **`dart build cli`** (see *Build installable bundles* below).

### Full backups (`backup create` / `backup restore` / `backup schedule`)

- **Create** (timestamped **`.zip`** or **`.tar.gz`** in the current directory, or under `--output`):

  `dart run waddlectl --database=/path/to/waddle_view.sqlite backup create`

  Defaults include **database** and **`media/`** next to the SQLite file. Toggle with `--no-include-database` or `--no-include-blobs`. Use `--format=zip` or `--format=tgz`. The SQLite file is checkpointed (**WAL** merged) before copy so the archive holds a single main DB file.

- **Restore** replaces the local **SQLite** file and **`media/`** tree for components that were included in the backup, after an interactive warning (type `yes`). Use **`--yes`** for automation (e.g. cron). Older archives whose manifest lists encrypted secrets are still restored for **database/media**; the legacy secret bundle is **not** merged (a warning is printed).

- **Schedule** prints a ready-to-paste **crontab** line and **systemd user** unit sketches (`backup schedule`); it does not install anything.

- **Archive layout**: `manifest.json`, `db/<sqlite basename>`, optional `media/...`. Legacy archives may also contain `secrets/secret_bundle.bin` (ignored on restore).

- **Data-only SQL seed** (`sqlite export-seed`): writes **DELETE + INSERT** statements for all user tables (foreign keys off during replay). Use **`--file=PATH`** or **`--stdout`**; default output is **`<stem>_seed.sql`** next to the database. Apply only on a file that **already matches** the current app schema (for example after the app created or migrated it). Do not commit exports that contain secrets.

## Build installable bundles (local)

Release binaries are what you ship or copy to a device (no hot reload).

```bash
flutter build windows --release
flutter build linux --release
(cd apps/waddlectl && dart build cli -o build/waddlectl_release)
```

- **Windows**: runnable under `build/windows/x64/runner/Release/` (launch `waddle_display.exe` from Explorer or a terminal). CI and release workflows also place **`waddlectl/bin/waddlectl.exe`** (and **`waddlectl/lib/`** native libs) under that same `Release/` directory.
- **Linux**: bundle under `build/linux/<arch>/release/bundle/` (e.g. `arm64` on an ARM64 host). Run the `waddle_display` executable from that **bundle** directory so assets resolve correctly. Release and CI merges add **`waddlectl/bin/waddlectl`** (and **`waddlectl/lib/`**) beside `waddle_display` inside `bundle/`.

**GitHub Releases:** pushing a **`v*`** tag runs **[`release.yml`](../../.github/workflows/release.yml)**, which calls **[`release-windows.yml`](../../.github/workflows/release-windows.yml)** (Windows **`.zip`**), **[`release-linux-x64.yml`](../../.github/workflows/release-linux-x64.yml)** (Linux x64 **`.tar.gz`**), and **[`release-pi.yml`](../../.github/workflows/release-pi.yml)** (Linux arm64 **`.tar.gz`**) and attaches all three to the GitHub Release. Each desktop bundle includes the display binary plus a native **`waddlectl`** tree (**`dart build cli`**). CI passes **`flutter build … --build-number`** using GitHub Actions **`github.run_number`**, so each workflow run gets a monotonic integer build id; **`pubspec.yaml`** `version: …+N` is **not** auto-synced to that number. The reusable release workflows are only invoked from **`release.yml`**; use **`workflow_dispatch`** on **`release.yml`** if you want CI builds without creating a GitHub Release (the publish step still runs only on **`v*`** tag pushes).

**PR / branch CI:** **[`ci.yml`](../../.github/workflows/ci.yml)** runs tests and analysis, then compiles a **Linux arm64 (Pi)** release bundle via **[`release-pi.yml`](../../.github/workflows/release-pi.yml)** (with **`waddlectl`** merged like tagged releases). **Linux x64** and **Windows** compile checks are **not** run in CI right now; catch desktop breakages locally or via a **`v*`** tag push (**`release.yml`** still builds all three platforms).

Tagged **Pi** tarballs and `install.sh` are produced in CI and documented under [`../../docs/pi/`](../../docs/pi/); templates live in [`../../deploy/linux-arm64/`](../../deploy/linux-arm64/).

## Deployed / Raspberry Pi (summary)

1. Obtain **`waddle-view-linux-arm64-<tag>.tar.gz`** (GitHub Releases or CI artifacts); verify **SHA256** when published.
2. On 64-bit Raspberry Pi OS, extract and run **`install.sh`** (installs under `/opt/waddle-view` by default, creates **`/etc/waddle-view/instance.id`** for operator reference—see REST section below).
3. Start the app from **`/opt/waddle-view/bundle/waddle_display`** with a graphical session (`DISPLAY` set for systemd/display). The same install includes **`/opt/waddle-view/bundle/waddlectl/bin/waddlectl`** for operator tasks against the SQLite file. Optional: **`waddle-view.service`** in `deploy/linux-arm64/`, autostart `.desktop`, disable screen blanking for display use.

Full steps, upgrades, and API examples: **[`docs/pi/using-the-image.md`](../../docs/pi/using-the-image.md)**, **[`docs/pi/upgrade.md`](../../docs/pi/upgrade.md)**, **[`docs/pi/api.md`](../../docs/pi/api.md)**.

### Content suppression (operator)

- Jokes, RSS articles, photos, videos, and trivia questions support a **`suppressed`** flag in SQLite (default false). When true, rows stay in the database (stable ids for providers that re-fetch the same item) but are **excluded** from the main carousel pools, slide fallbacks, RSS **ticker** candidates, and RSS feed **pruning deletes** (non-suppressed rows are still trimmed per `max_articles`).
- **REST** (authenticated like other `/v1/*` routes): `PATCH` with JSON `{"suppressed": true|false}` to:
  - `/v1/content/jokes/<id>`
  - `/v1/content/rss-articles/<id>`
  - `/v1/content/photos/<id>`
  - `/v1/content/videos/<id>`
  - `/v1/content/trivia/<id>`
- **`404`** when the id does not exist. Full table and examples: **[`docs/pi/api.md`](../../docs/pi/api.md)**.

### Reject word list (curse-word filter)

- SQLite table **`curator_rejected_terms`** (renamed from `reject_terms` in schema **42**) holds operator-managed words. Each row has an **`action`**:
  - **`block`** — at **ingest time** providers set **`suppressed = true`** when the term appears in any text field, photographer name, alt text, or URL part (URL separators like `-`, `_`, `/`, `?`, `=`, `&`, `.` are normalized to spaces for whole-word matching). Media matches (Pexels, Bing, Flickr, OneDrive) **always** block, even when the matching term's action is `censor`.
  - **`censor`** — at **slide and ticker load time** the matched word is replaced with a configurable mask **transiently** (the SQLite row is untouched). The censor format lives in **`config_key_values`** under **`curator.reject.censorFormat`** with values **`asterisks_full`** (default), **`asterisks_fixed`** (always 4 asterisks), **`first_last`** (keeps first and last character, masks middle), or **`bracketed_token`** (replaces with `[censored]`).
- Matching is case-insensitive and word-boundary aware so substring noise (e.g. *class* containing *ass*) does not trigger.
- A set of common defaults is seeded by [`reject_term_defaults.dart`](../../packages/waddle_shared/lib/persistence/reject_term_defaults.dart) on first run; remove or replace any of them via REST / `waddlectl`.
- On every startup, the display app re-evaluates stored content against the current list and updates `suppressed = true` for new matches (already-suppressed rows are left alone). The REST and `waddlectl` mutators trigger the same rescan so operator changes apply to content already in the database, not just future ingests.
- **REST** (authenticated like other `/v1/*` routes):
  - `GET /v1/reject-terms` — list current terms and the active censor format.
  - `POST /v1/reject-terms` — upsert by term (`{"term":"foo","action":"censor"|"block"}`).
  - `PATCH /v1/reject-terms/<id>` — update an existing row by id.
  - `DELETE /v1/reject-terms/<id>` — remove a row.
  - `PUT /v1/reject-terms/format` — set the censor mask format (`{"format":"asterisks_full"}` etc.).
  - `POST /v1/reject-terms/rescan` — manually re-evaluate stored content; returns per-table counts.
- **`waddlectl`** (local operator CLI):
  - `waddlectl reject list`
  - `waddlectl reject add --action=<block|censor> <term>`
  - `waddlectl reject remove <term>` (or `--by-id <id>`)
  - `waddlectl reject format set <asterisks_full|asterisks_fixed|first_last|bracketed_token>`
  - `waddlectl reject rescan`

## Local REST API and admin UI (debug, profile, release)

- Defaults to **`0.0.0.0:8787`** (all interfaces; QR/adoption URLs use the first non-loopback IPv4). Set `WADDLE_DISPLAY_HTTP_BIND_IP=127.0.0.1` for loopback-only, or optional `WADDLE_DISPLAY_HTTP_PORT`.
- **Authentication**: adopt via **`POST /v1/adoption/request`** and **`POST /v1/adoption/confirm`** (see [`docs/pi/api.md`](../../docs/pi/api.md)), then send **`Authorization: Bearer <api_key>`** on protected routes. Only **`/v1/health`** and **`/v1/adoption/*`** are public.
- **Instance id file**: **`waddle_instance.id`** in Flutter’s **application support** directory (`getApplicationSupportDirectory()` in `lib/main.dart`). Created on first launch; legacy **`waddle_api.key`** is renamed on upgrade. Used as the HMAC secret for adoption challenges and API keys (not sent as the bearer token).
- Protected `/v1/*` routes return **401** without a valid API key, **403** when the adopted client’s role lacks permission.
- **Operator UI**: **`apps/waddle_controller`** pairs via adoption and stores per-display API keys in the browser. Role semantics (`viewer`, `power_viewer`, `operator`, `admin`) are unchanged on protected routes — see **`docs/pi/api.md`**.
- **Operator JSON API** (telemetry, navigation, screens, ticker, integrations, curator, catalog): **[`docs/pi/api.md`](../../docs/pi/api.md)**. **CORS**: adoption routes allow LAN/private origins; successful adoption stores the caller origin for protected routes. Optionally seed static origins with **`WADDLE_DISPLAY_HTTP_CORS_ORIGINS`** (see **`.env.example`**). The Vite dev proxy avoids CORS during local controller dev.

### Display theme (`config_key_values`)

- **Key**: `display.theme.id`
- **Values**: `navy_coral` (default), `graphite_amber`, plus ten Coolors trending presets: `teal_gold_sunset`, `ocean_depth`, `forest_cream`, `heritage_coast`, `plum_ember`, `slate_crimson`, `wine_ember`, `dopamine_pop`, `sage_wellness`, `warm_minimal` (hex sources in [`lib/theme/config/palettes/coolors_trending_palettes.dart`](lib/theme/config/palettes/coolors_trending_palettes.dart))
- **Operator UI**: Admin home → Curator → **Display theme** (saved with other curator settings).
- **Code**: palettes and builders live under [`lib/theme/config/`](lib/theme/config/); registered ids are listed in [`lib/theme/config/display_theme_registry.dart`](lib/theme/config/display_theme_registry.dart).
- **Default palette details** (`navy_coral`): primary starts at `#0D1B2A` and follows a 9-color sequence: five neutrals, then four accents (`#83AF84`, `#E05C6C`, `#FFE356`, `#966CB3`). The theme also exposes a `PaletteTertiaryLayers` extension (including `accent1`–`accent4`) with 4 tertiary layers for each palette color, plus gradients for the first pair (`#0D1B2A` → `#1B263B`) and next pair (`#415A77` → `#778DA9`).
- **Icon color**: the default icon color is `dustyDenim` (`#778DA9`) via theme `IconThemeData` and `PaletteTertiaryLayers.iconColor`. Multi-icon screens may use accent colors for emphasis (for example, current weather icon) while secondary icons keep the standard icon color.

### Display time zone (`config_key_values`)

- **Key**: `display.timezone`
- **Values**: any valid **IANA** time zone id (for example `America/New_York`, `America/Chicago`, `Europe/London`). Calendar event **times** and **day boundaries** on the **`calendar_month`** slide use this zone; instants in **`calendar_events`** remain stored as absolute times (milliseconds); the app does not reinterpret stored UTC instants when you change this key.
- **Default**: first seed inserts **`America/New_York`**. Empty or unknown values fall back to that default.
- **Code**: [`lib/config/display_timezone.dart`](lib/config/display_timezone.dart) and [`packages/waddle_shared/lib/persistence/tables.dart`](../../packages/waddle_shared/lib/persistence/tables.dart) (`kDisplayTimezoneKvKey`).

### Festive display overlays (`overlays` + REST)

- **Effect**: on matching calendar days, an **unobtrusive** translucent layer sits **above** slides and ticker but **below** priority **alert** overlays, and it does **not** capture pointer or keyboard input.
- **`hearts_rain`**: floating **hearts** ♥ and occasional **short phrases** from `config_json.messages`, tinted from the current theme’s **accent** palette (`PaletteTertiaryLayers` / `ColorScheme` fallback).
- **`birthday_confetti`**: low-opacity **falling confetti** (rectangles, circles, stars, thin “streamers”) with optional **sparse** phrases from `config_json.messages`. Other **`config_json`** keys tune **`shapes`** (`rect`, `circle`, `star`, `streamer`, `mix`), optional **`colors`** (`#RRGGBB` or `#AARRGGBB`), **`density`** (about **0.15–0.9**, displayed clamped for subtlety), **`message_interval_sec`** (about **8–120** sec between occasional phrases), **`fall_speed`** (**0.02–1.8**, lower = slower drift; **~1.0** matches the original ~5s vertical cycle; **0.02** is the slowest supported, about **4.2 minutes** per full cycle with the current cap), and **`opacity`** (**0.12–0.72**, caps per-piece alpha for stronger or softer confetti). Empty `messages` means **no** overlay text. **`hearts_rain`** upserts normalize to **`{"messages":[…]}`** only.
- **`bouncing_message`**: a **single line** of text from **`config_json.messages`** (first string; if none, the app uses **`Happy Birthday Waddle!!`**) **bounces** within the overlay like a DVD logo. Other **`config_json`** keys may set **`color`** (`#RRGGBB` / `#AARRGGBB`), **`font_family`**, **`font_size`** (**14–96**), **`font_weight`** (**100–900**, snapped to hundreds, or a numeric string), **`letter_spacing`** (**-1.5–6**), **`shadow`** (bool), and **`speed`** (**0.25–2.5**, velocity multiplier).
- **Stacking**: when several kinds match, **confetti** is lowest, then **hearts**, then **bouncing message** on top for readability.
- **Multiple rows**: merged **message** strings are **deduped** across matching rows (sorted by `id`). For **`birthday_confetti`**, **visual settings** come from the **first** matching row by `id` only; add a dedicated row per distinct look, or keep a single confetti schedule. **`bouncing_message`** uses the **first** matching row’s `config_json` and the **first** merged phrase for the moving text.
- **Global switch**: `config_key_values` key **`display.overlay.enabled`**. **Omit** or any value other than **`false`**, **`0`**, **`no`**, **`off`** means **on**. Set to `false` to disable all overlays without deleting rows.
- **Storage**: SQLite **`overlays`** (migration **41** copies legacy `display_overlay_schedules` when present; fresh databases at schema **42** create **`overlays`** directly). Column **`overlay_type`** replaces **`overlay_kind`**; legacy **`messages_json`** is merged into **`config_json.messages`** on upgrade. Rows support **fixed** calendar ranges (`start_month`/`start_day`, optional inclusive `end_*`) or **`nth_week_of_month` + `nth_weekday`** using Dart **`DateTime.weekday`** (Monday=1 … Sunday=7) with `start_month` holding the anchor month (`start_day` is ignored in that mode).
- **Types**: **`overlay_type`** uses the same slug style as **`screen_type`**. Built-in renderers today: **`hearts_rain`**, **`birthday_confetti`**, **`bouncing_message`**. Additional types may be stored and edited over REST; the display ignores unknown types until a renderer exists.
- **Default seeds**: id **`default_mothers_day_us`** — US **Mother’s Day** (2nd Sunday in May) with message **`Happy Mother's Day!`** (`hearts_rain`, **enabled**). Id **`default_birthday_example_may_13`** — **May 13** each year, **`birthday_confetti`** with example message and a **slower, brighter** stock `config_json`, **disabled** so operators can enable or edit via REST without affecting installs until they choose to. Id **`default_bouncing_message_may_13`** — **May 13** each year, **`bouncing_message`** with **`Happy Birthday Waddle!!`** and stock typography `config_json`, **disabled** (same intent as the birthday example).
- **REST** (authenticated like other `/v1/*` routes):
  - `GET /v1/display/overlays` — list schedules (`config_json`, `config_json_schema`, and `example_config_json` decoded as JSON in the response when valid).
  - `POST /v1/display/overlays` — upsert (requires `id`; include `start_month` / `start_day` for fixed mode, or `nth_week_of_month` / `nth_weekday` for floating holidays).
  - `PATCH /v1/display/overlays/{id}` — partial update (merge with existing row; `config_json` merges shallowly at the top level).
  - `DELETE /v1/display/overlays/{id}` — remove a schedule.
- **Details and curl examples**: [`docs/pi/api.md`](../../docs/pi/api.md).

### Screen program (main carousel)

When the app assembles a timed program from `screens`, [`ScreenProgramCurator`](lib/curator/screen_program_curator.dart) pre-assigns **content ids** on each [`ResolvedSlide`](lib/curator/screen_program_curator.dart) for **jokes**, **RSS articles**, **trivia** (and existing **random photo** pools). Slide widgets read those ids from `randomChoices` first, so the same joke or article is not shown twice in one program when SQLite has enough distinct rows. If every candidate is already used, the slide falls back to the previous random / “best article” selection. Multi-article RSS widgets use suffixed keys, for example **`main_rss_article_columns_0`** … **`_2`**, or **`main_rss_article_stack_0`** / **`_1`** for the two-row stack layout ([`rss_article_stack_slide_widget.dart`](lib/display/screens/rss_article/rss_article_stack_slide_widget.dart)). The **`rss_article_columns`** layout places a **QR code** under each column’s **title** (start-aligned) with the **summary beside it** when that article’s `link` is non-empty; optional widget `config` **`qrLogicalSize`** (default **80**, clamped) scales the code after the viewport multiplier ([`rss_article_columns_slide_widget.dart`](lib/display/screens/rss_article/rss_article_columns_slide_widget.dart)).

RSS widget `config` may include **`feedId`** (single feed), **`categoryId`** (slug shared with **`content_categories.id`**, pool key **`rss_category:<id>`**), or neither. With the global **`rss`** pool, the curator assigns articles from **one** category per slide so columns/stack rows do not mix unrelated feeds; it stores that id in **`randomChoices`** under **`rss_screen_category_id`** ([`ScreenProgramCurator.rssScreenCategoryChoiceKey`](lib/curator/screen_program_curator.dart)). **RSS**, **joke**, and **trivia** slides render a **category strip** at the top (label + icon from **`content_categories`**, with fallbacks — [`content_category_slide_header.dart`](lib/display/content_category_slide_header.dart)).

Each **`screens`** row stores **`screen_type`** (widget id, e.g. `weather`, `rss_article`), runtime **`config_json`** (JSON object: the former per-widget `config` in legacy `layout_json`), plus documentation columns **`config_json_schema`** and **`example_config_json`** for that config shape. `GET /v1/screens` includes the schema and example fields.

- **Analog clock labels** — optional `analog_clock` widget `config.dialLabels` controls clock-face labels: **`none`** (default), **`numbers`** (1-12), **`roman`** (I-XII), or **`cardinal_numbers`** (12/3/6/9 only).
- **Analog clock hand accents** — by default, hands use accent colors **1/2/3** for **hour/minute/second**. Optional per-hand config keys can override accent choice: **`hourHandAccent`**, **`minuteHandAccent`**, **`secondHandAccent`** with values **`accent1`**, **`accent2`**, **`accent3`** (or numeric **`1`**, **`2`**, **`3`**).
- **RSS screen photos** — config key **`curator.news.screens.require_photo`** (default **true** in seed): when true, only RSS rows with a downloaded image are used for **screen** slides; the **ticker** is unchanged. If a news screen must still run (e.g. **min placements** / data-key minimum) and no image-backed article is available, the curator may place a photo-less row and set **`*_imageMode`** = **`icon`** (per slot for columns/stack) so the UI shows a **newspaper** icon instead of a photo.
- **Summary fit** — optional keys in **`config_json`** for RSS screens: **`summaryCapacityChars`** (single `rss_article`), **`summaryCapacityCharsPerColumn`** (`rss_article_columns`), **`summaryCapacityCharsPerSlot`** (`rss_article_stack`). The curator scores screen+article pairs so summary text length is less likely to be wasted or heavily truncated. Seeded default news screens set these in [`initial_seed.dart`](../../packages/waddle_shared/lib/seed/initial_seed.dart).

### Bottom ticker (`ticker_tapes`)

SQLite table **`ticker_tapes`** configures the bottom marquee: which **types** run (`time`, `weather`, `news`, `quote`, `stocks`, `custom`), **order** (`sort_order`, then id), **`enabled`**, and **`frequency_weight`** (repeat that type’s item bundle that many times when building the curated list; identical bodies are still deduplicated). Each row has **`config_json`**: for **`weather`**, **`news`**, and **`quote`**, optional **`fallbackText`** is used when live weather, RSS articles, or (for quote) nothing else supplies a line. **`custom`** rows may set **`config_key`** to pin one `ticker.marquee.*` key in **`config_key_values`**; when null, every **`ticker.marquee.*`** key in **`config_key_values`** is included for that tape (sorted).

Live weather plus **active NWS alerts** (same `weather` ticker kind), stored RSS articles for **`news`**, and enabled **`stock_symbols`** / **`stock_quotes`** for **`stocks`** are read from their domain tables. **`curator.ticker.*`** keys in **`config_key_values`** still tune RSS width budgeting for the news slice. If **`ticker_tapes`** has **no rows** (empty table), curation uses a legacy path: **time**, live weather (if any), RSS news, then every **`ticker.marquee.*`** value in **`config_key_values`** as **`custom`** lines — **without** stock lines. If the table has rows but **none are enabled**, curation falls back to **time** only.

Seeded defaults: **`ticker_time`** … **`ticker_stocks`** enabled, **`ticker_custom`** disabled ([`initial_seed.dart`](../../packages/waddle_shared/lib/seed/initial_seed.dart)).

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
- On manual navigation, a timeline overlay appears at the bottom of the screen area (above ticker) and highlights the current screen by `screens.id`.
- At the oldest history boundary, the overlay shows an end-of-history message.
- If no arrow key is pressed for a few seconds, overlays fade out and automatic dwell-based rotation resumes.

Startup logs include **`REST listening at …`** with the bound **base URL**. To show the same information on the TV carousel, enable the **`dev_local_api`** row in **`screens`** (`enabled = 1`); that developer slide shows the URL and **`waddle_instance.id`** / login hints.

The **`dev_data_health`** screen (`screen_type` **`data_health`**, installed **disabled**) shows a **data health** dashboard: active content as a **pie chart** by type (RSS, photos, videos, jokes, trivia), **paired pie charts** for photos vs videos by category with a full-width legend (no truncated axis labels), RSS image coverage, feed enable/retry hints, calendar row count, and blob-store size. Optional `config_json`: **`headline`** (string) and **`refreshIntervalSeconds`** (15–300, default 45) for how often aggregates refresh while the slide is visible. Enable the row like any other screen (REST **`GET`/`PATCH `/v1/screens`**, Admin UI, or SQLite).

## Raspberry Pi / Linux runtime notes

- **GTK / libgtk-3** and typical Flutter Linux build deps (`clang`, `cmake`, `ninja-build`, `pkg-config`).
- **Secret storage**: `flutter_secure_storage` uses the Secret Service / **libsecret** where available; headless images without D-Bus may need a documented fallback (see repo **`docs/pi/`**).
- **Data**: SQLite and **`media/`** live under the application support directory (see `path_provider` on device).

The **`curator_categories`** table (renamed from **`content_categories`** in schema **42**) holds shared category ids for **RSS** (`rss_feed_sources.category`), **Pexels** (`photos.category` / `videos.category`), **jokes** (`joke_categories.id`), and **trivia** (`trivia_categories.id`). Each row has a display **`label`**, optional **`material_icon_name`** (resolved in the app via [`content_category_material_icon.dart`](lib/display/content_category_material_icon.dart)), and optional **`icon_blob_key`** for a custom image in the blob store. Initial rows are created by migration to schema version **19** and by [`ensureDefaultContentCategories`](../../packages/waddle_shared/lib/seed/tables/content_categories_seed.dart) during startup seeding.

## Provider secrets (OpenAI / joke_openai / trivia_openai)

The joke and trivia data providers read OpenAI-style API keys from **environment variables** (merged with debug `.env`), not from the **`integrations`** table or other SQLite configuration.

Supported env name: **`WADDLE_DISPLAY_OPENAI_API_KEY`** (shared by **`joke_openai`** and **`trivia_openai`** (and **`trivia_opentdb`**); see [`packages/waddle_shared/lib/config/provider_access_token_env.dart`](../../packages/waddle_shared/lib/config/provider_access_token_env.dart)).

The **`weather_openweathermap`** data provider uses **`WADDLE_DISPLAY_OPEN_WEATHER_MAP_API_KEY`**.

**Local onboarding:** copy **[`.env.example`](.env.example)** to **`.env`** in this directory and set the variables above. In **debug** builds, the app loads that file into the merged env map (see [`lib/config/dev_dotenv_secrets.dart`](lib/config/dev_dotenv_secrets.dart)). **Google / Microsoft Graph** OAuth **tokens** use **`SecretStore`** only (device-code flow or `waddlectl secrets set`); set public **client ids** with **`WADDLE_DISPLAY_GOOGLE_CLIENT_ID`** and **`WADDLE_DISPLAY_MICROSOFT_GRAPH_CLIENT_ID`** in the environment (or the same debug `.env`). Full detail: **[`docs/pi/development.md`](../../docs/pi/development.md#joke-data-provider-openai-api-key)**.

OpenTDB trivia does **not** require a token.

### Trivia provider (`provider_type`: **`trivia_openai`**)

The trivia data provider calls OpenAI Chat Completions, then upserts rows into **`trivia_questions`**. Eligible **`trivia_categories`** are cycled in **round-robin** order (starting offset rotates each hour). Each request’s user prompt includes **recent question stems** so the model avoids obvious repeats.

**`integrations.config_json`** (canonical keys):

- **`maxQuestionPerDay`**: cap on new questions created per local calendar day (default **200**). Legacy **`questionsPerDay`** is still read if **`maxQuestionPerDay`** is omitted.
- **`maxQuestionPerHour`**: cap on questions **requested** in a rolling window (default **20** per **`twoHourWindowMs`**). Legacy **`maxQuestionsPerTwoHours`** is still read if **`maxQuestionPerHour`** is omitted.
- **`twoHourWindowMs`**: rolling window length in milliseconds (default **3600000**, one hour).
- **`questionRetentionDays`**: trivia older than this many days is deleted on collect (default **15**; **`≤ 0`** disables purge).
- **`model`**, **`globalPrompt`** / **`systemPrompt`**, optional **`temperature`**, **`maxOutputTokens`**.
- Optional **`questionType`** hint in generated payload supports `multiple_choice` and `true_false`.

True/false rows store options in A/B and leave C/D blank; the slide renders and reveals two choices accordingly.

### OpenTDB trivia provider (`provider_type`: **`trivia_opentdb`**)

The OpenTDB provider fetches questions from [Open Trivia DB](https://opentdb.com/api_config.php) and writes them into the same **`trivia_questions`** table as the OpenAI trivia provider.

**`integrations.config_json`** keys:

- **`amount`**: number of questions per request (1-50, default 10).
- **`difficulty`**: optional `easy`, `medium`, or `hard`.
- **`questionType`**: optional `multiple` or `boolean`.
- **`categoryMap`**: maps local `trivia_categories.id` to OpenTDB numeric category ids.
- **`questionRetentionDays`**: retention window (same behavior as `trivia` provider).
- **`maxQuestionChars`**, **`maxOptionChars`**: reject oversized questions/answers.

Generated text must stay short (enforced in prompts and validation): question **≤ 90** characters, each option **≤ 45** characters. Duplicate **normalized** question text in the same category is skipped.

## Pexels photos / videos provider

The **Pexels** provider (`id` / `provider_type`: **`media_pexels`**) downloads curated photos (`GET /v1/curated`) and popular videos (`GET /v1/videos/popular` with duration bounds), stores binaries in the **blob** store, and keeps metadata in **`photos`** and **`videos`** (with **`data_provider`** set to the provider id, e.g. **`media_pexels`**). API key: **`WADDLE_DISPLAY_PEXELS_API_KEY`** environment variable (never in SQLite).

**Debug `.env`:** **`WADDLE_DISPLAY_PEXELS_API_KEY`** (see [`.env.example`](.env.example)).

**`integrations.config_json`** (JSON) holds the runtime payload. **`config_json_schema`** and **`example_config_json`** are documentation columns (JSON Schema and sample JSON) populated per row type.

**`config_json`** for Pexels supports:

- **`maxPhotos`** / **`maxVideos`**: retention cap (default 100); oldest rows are removed with their blobs.
- **`photosPerHour`** / **`videosPerHour`**: rolling 60-minute download caps (default 2 each).
- **`minVideoSeconds`** / **`maxVideoSeconds`**: inclusive duration window for videos (defaults **11** and **29** seconds).
- **`sources`**: optional list of `{ "query": "…", "category": "…" }` for `/v1/search` (photos) and `/v1/videos/search` (videos); results use that **category** string (the default curated/popular path uses category **`pexels`**).

**Screens:** widget types **`pexels_photo`**, **`pexels_photo_collage`** (multi-tile layouts; `config.template` picks one of the built-in grids, and the curator matches **native aspect ratio** to each cell when **`blob_metadata.pixel_width` / `pixel_height`** are populated), and **`pexels_video`**. Optional `config.categoryId` selects the curator pool (`pexels_photo` vs `pexels_photo:<category>`). Seed adds **`pexels_photo`**, several collage screens, and **`pexels_video`** rows in **`screens`** disabled by default; enable after configuring the API key. Attribution (photographer name, profile URL, alt text) is shown on the photo slide; videos autoplay **muted** unless `config.unmuted` is true.

## Stock quote provider (Finnhub)

The **stocks** provider (`id` / `provider_type`: **`stock_finnhub`**) calls [Finnhub](https://finnhub.io/docs/api/quote) **`GET /api/v1/quote?symbol=...&token=...`** for every enabled row in **`stock_symbols`** and upserts the latest quote into **`stock_quotes`** (one row per symbol). API key: **`WADDLE_DISPLAY_FINHUB_API_KEY`** (never in SQLite).

**Debug `.env`:** **`WADDLE_DISPLAY_FINHUB_API_KEY`** (see [`.env.example`](.env.example)).

**Symbol management:** seed inserts AAPL / MSFT / GOOG / NVDA / AMZN with **AAPL** and **MSFT** enabled by default; toggle [`StockSymbols.enabled`](../../packages/waddle_shared/lib/persistence/tables.dart) to add or remove symbols at runtime. When `stock_symbols` has no enabled rows the provider falls back to **`config_json.defaultSymbols`** and writes those entries into the table on first collect so the slide widget can display them.

**`config_json`** for stocks supports:

- **`maxSymbolsPerCollect`**: ceiling on quote requests per tick (default **25**).
- **`defaultSymbols`**: list of `{ "symbol": "...", "displayName": "..." }` entries used when `stock_symbols` is empty.

**Schema:** **`stock_symbols(id, symbol, display_name, enabled)`** and **`stock_quotes(symbol_id, current_price, change_amount, percent_change, high_of_day, low_of_day, open_price, previous_close, quoted_at_ms, observed_at_ms)`** are added in schema version **21**.

**Screen:** widget type **`stock_quotes`**. Seed adds a **`stock_quotes`** row in **`screens`** disabled by default; enable after configuring the API key. The slide renders symbol, price, and percent change with up/down trend coloring per enabled symbol.

## NWS weather alerts (api.weather.gov)

The **`weather_nws_alerts`** data provider (`id` / `provider_type`: **`weather_nws_alerts`**; legacy DBs migrated from **`nws_weather_alerts`**) calls the National Weather Service [JSON API](https://www.weather.gov/documentation/services-web-api) **`GET /alerts/active?point=<lat>,<lon>`** for each enabled **`weather_locations`** row with **`include_active_weather_alerts`** true (schema version **29**; default **true**). When no rows are enabled for weather, it uses **`defaultLocation`** from **`config_json`** (same shape as the OpenWeather provider), like the OpenWeather collector. If every enabled location opts out of active alerts, stored **`weather_alerts`** rows are cleared and no NWS requests are made. Responses are stored in **`weather_alerts`** (schema version **25**). **No API key** is required.

**Schema 26** adds boolean **`suppressed`** on **`jokes`**, **`rss_articles`**, **`trivia_questions`**, **`photos`**, and **`videos`** (hide from display without deleting rows; see *Content suppression* above).

**Schema 30** adds **`consecutive_failures`** (int, default 0) and **`next_retry_at`** (nullable) on **`rss_feed_sources`**. The RSS provider increments **`consecutive_failures`** on any non-200 response, network throw, or parse error, and schedules the next attempt at `now + pollSeconds * 2^(failures-1)` (capped at 24h). A successful collect resets the counter and clears **`next_retry_at`**. After **5** consecutive failures the feed is force-disabled (**`enabled = false`**) so the engine stops trying — re-enable via the database / REST when the source is healthy again.

**Schema 31** adds the **`reject_terms`** table (`id`, `term`, `action`, `created_at_ms`, `updated_at_ms`) for the curse-word reject list. See **Reject word list** above for the operator workflow.

**User-Agent (required by NWS):** every request sends an identifying **`User-Agent`** header. Set **`userAgent`** in **`integrations.config_json`** to a string that includes contact information (website or email), for example `(https://example.org, ops@example.org)`, as described in the [API overview](https://www.weather.gov/documentation/services-web-api). Until you configure this, the app uses a generic placeholder string that points to this README.

**Coverage:** alerts are **US-only** (NWS). **`integrations.base_url`** defaults to **`https://api.weather.gov`**.

**UI:** the **`weather`** slide shows an **Active alerts** section when rows exist for the slide’s location. When the marquee includes a **`weather`** ticker definition (or legacy ordering), each active alert adds an extra **`weather`-kind** ticker line after the temperature summary (deduped by NWS alert id across locations).

**`integrations.poll_seconds`:** default **900** when seeded (aligned with the OpenWeather provider).

## Outlook calendar (Microsoft Graph)

The **Outlook calendar** provider (`id` / `provider_type`: **`calendar_outlook`**) reads delegated calendar data via [Microsoft Graph](https://learn.microsoft.com/en-us/graph/api/resources/calendar) `calendarView` and stores events in **`calendar_events`** (shown on the **`calendar_month`** slide). Seed adds the provider **disabled** by default; set **`integrations.enabled`** after configuration.

**App registration (Entra ID):** delegated permissions **`Calendars.Read`**, **`Files.Read`** (for OneDrive media sync), **`User.Read`**, and **`offline_access`**. The shared public **application (client) id** is read from the environment as **`WADDLE_DISPLAY_MICROSOFT_GRAPH_CLIENT_ID`** (process env or merged debug `.env`) — not from SQLite. Other Graph-based providers use the same variable. If you already signed in before **`Files.Read`** was added, the next token refresh may fall back to **device code** once so you can re-consent for the broader scope.

**Authentication platform:** turn on **Allow public client flows** (device code). Under **Authentication**, add a **Mobile and desktop applications** redirect URI **`https://login.microsoftonline.com/common/oauth2/nativeclient`** (same value the app sends as `redirect_uri` on token and device-code requests). Without this, Entra may return errors such as a missing **`redirect_uri`** on the request.

**SecretStore keys (per Microsoft account, not per provider row):**

- Access: **`provider:access_token:microsoft_graph:<graphAccountKey>`**
- Refresh: **`provider:refresh_token:microsoft_graph:<graphAccountKey>`**

**OAuth:** when access and refresh tokens are missing or expired, the provider starts the **device code** flow. An **`alerts`** row shows the **user code** and verification URL on the dashboard, and a **QR code** (when the identity platform returns `verification_uri_complete`, otherwise the base verification URL) so you can open the sign-in page on a phone. Repeated prompts are throttled (per account) after the last device-code attempt.

**`integrations.config_json`** (JSON):

- **`accounts`**: list of `{ "graphAccountKey": "<id>", "sources": [ ... ] }`. Each **`graphAccountKey`** must match the suffix used in SecretStore (e.g. `personal`, `work`).
- **`sources`**: list of mailbox objects. **`mailbox`** is the Graph user (`me` or a UPN). **`calendars`**: display names or Graph calendar ids, each either a **string** or `{ "calendar": "Name", "categoryId": "<content_categories.id>" }` (alias: **`category`**) to force a **content category** for every event from that calendar. An **empty** `calendars` array means the user’s **default** calendar only; optional **`defaultCategoryId`** (alias: **`defaultCategory`**) then applies to those events. Optional **`categoryMap`** maps **Outlook** event category labels (Graph `categories`) to **`content_categories.id`** when no per-calendar override applies.
- **`pastDays`** / **`futureDays`**: inclusive window around **today’s UTC midnight** (defaults **14** / **14**).

**`calendar_events`** (schema **22+**) also stores **`ical_uid`** (for deduplication across calendars) and optional **`category_id`** (FK to **`content_categories`**). The **`calendar_month`** slide shows a category **icon** when present, **deduplicates** shared meetings, and **reuses** one time label for events at the same clock time or for **all-day** items on the same day. The month grid uses **accent squares** at the top of a day for **all-day** events and **accent dots** along the bottom for timed events (colors vary by **`category_id`**, **`source`**, and event id); the **Upcoming events** list shows a **larger** matching square or dot beside each row using the same color rule. Day cells **outside the displayed month** stay visually light (no fill tint); **in-month days after today** use a stronger **surface** tint than **in-month days before today**; **today** keeps the **secondary container** highlight. **Widget `config`** (optional): **`upcomingTime12Hour`** (default **true**) for `h:mm AM/PM` vs 24-hour; **`upcomingTimeNoonLabel`** (default **`Noon`**) for exactly 12:00 PM local; **`upcomingTimeWidthCompact`** / **`upcomingTimeWidth`** (default **132** / **156** logical px before TV scale) for the upcoming-events time column.

**`integrations.poll_seconds`:** default **3600** (one sync per hour when enabled).

**Schema 37** deletes legacy **`microsoft.graph.client_id`** / **`google.client_id`** rows from **`config_key_values`**; use **`WADDLE_DISPLAY_MICROSOFT_GRAPH_CLIENT_ID`** / **`WADDLE_DISPLAY_GOOGLE_CLIENT_ID`** in the environment instead.

## Google Calendar

The **Google Calendar** provider (`id` / `provider_type`: **`calendar_google`**) reads calendars/events from [Google Calendar API](https://developers.google.com/calendar/api/v3/reference) and stores normalized rows in **`calendar_events`** for the **`calendar_month`** slide.

Seed adds the provider **disabled** by default. Configure and enable in `integrations` when ready.

**OAuth client id:** set **`WADDLE_DISPLAY_GOOGLE_CLIENT_ID`** in the process environment (or merged debug `.env`) to your Google OAuth client id — not in `config_key_values`.

**SecretStore keys (per Google account):**

- Access: **`provider:access_token:google:<googleAccountKey>`**
- Refresh: **`provider:refresh_token:google:<googleAccountKey>`**

**OAuth:** when cached access/refresh tokens are unavailable or expired, the provider starts OAuth **device authorization**. An `alerts` row shows the user code and verification URL so an operator can approve access on another device.

**`integrations.config_json`** (JSON):

- **`accounts`**: list of `{ "googleAccountKey": "<id>", "sources": [ ... ] }`. Each `googleAccountKey` must match SecretStore key suffixes.
- **`sources`**: list of `{ "calendars": [ ... ], "defaultCategoryId": "<optional>" }` (alias: **`defaultCategory`**). Each calendar entry is a **string** or `{ "calendar": "primary", "categoryId": "<slug>" }` (alias: **`category`**). Empty `calendars` defaults to **`primary`** for that account; **`defaultCategoryId`** applies when using that default or as a fallback for entries without their own **`categoryId`**.
- **`pastDays`** / **`futureDays`**: sync window around today’s UTC midnight (defaults **14** / **14**).

**`integrations.poll_seconds`:** default **3600**.

## OneDrive media (Microsoft Graph)

The **OneDrive media** provider (`id` / `provider_type`: **`media_onedrive`**) keeps a **read-only local mirror** of folders on the signed-in user’s **personal OneDrive** (`/me/drive/...`). It uses Microsoft Graph **driveItem delta** (not shallow folder listing): each configured **`path`** is synced **recursively** (the entire subtree). The app only **GETs** metadata and file bytes from Graph—it **never** uploads or deletes anything in OneDrive. Items removed in OneDrive appear in the delta feed with a **`deleted`** facet and are **removed locally** ( **`photos`** / **`videos`** row and blob). Supported images and videos are stored with **`data_provider`** = **`media_onedrive`**. It reuses the same **SecretStore** keys and **device-code** flow as Outlook (**`provider:access_token:microsoft_graph:<graphAccountKey>`** / **`provider:refresh_token:...`**). Seed adds the row **disabled** by default.

**`integrations.config_json`** (JSON):

- **`accounts`**: list of `{ "graphAccountKey": "<id>", "sources": [ ... ] }` (same account keys as Outlook).
- **`sources`**: list of `{ "path": "/Pictures/MyFolder", "kind": "photo" | "video" | "both", "category": "<slug>", "maxFiles": <n>, "perPollLimit": <optional> }`. **`path`** is root-relative (leading `/` optional). Use **`""`** for the **drive root** (entire default drive—can be large). Multiple sources that share the same **`graphAccountKey`** and normalized **`path`** run **one** delta pass per collect. **`kind`**: **`both`** ingests supported photo and video MIME types into the same **`category`** (photos go to **`photos`**, videos to **`videos`**). **`category`** must match a **`content_categories.id`** (and optional **`config.categoryId`** on **`pexels_photo`** / **`pexels_video`** screens). **`maxFiles`**: retention cap per table for that category—oldest OneDrive-sourced rows in that table may be removed with their blobs **even if the file still exists in OneDrive** (separate from cloud-driven deletes). **`perPollLimit`**: max **new** downloads per collect for that source; omit to use **`maxFiles`**. **`globalPerPollLimit`**: cap on new downloads per engine cycle across all sources (default **50**). The provider persists **`@odata.deltaLink`** in app KV per account and path for incremental sync; if Graph returns **410** / resync, it clears the link and re-enumerates locally (still pull-only).

**MIME types:** photos **`image/jpeg`**, **`image/png`**, **`image/webp`**, **`image/gif`**; videos **`video/mp4`**, **`video/quicktime`**.

**Screens:** use existing **`pexels_photo`** / **`pexels_video`** widgets; set **`config.categoryId`** to the same slug as the folder’s **`category`** so the curator pool includes OneDrive items alongside Pexels (or use a dedicated category for OneDrive-only folders).

**`integrations.poll_seconds`:** default **3600** when seeded.

## Flickr group photos

The **Flickr media** provider (`id` / `provider_type`: **`media_flickr`**) pulls **public** photos from one or more Flickr groups using `flickr.groups.pools.getPhotos`, downloads image bytes, and stores rows in **`photos`** with **`data_provider`** = **`media_flickr`**.

The **Flickr** provider … **API key:** **`WADDLE_DISPLAY_FLICKR_API_KEY`** (never in SQLite).

**`integrations.config_json`** (JSON):

- **`groupIds`**: array of Flickr group NSIDs to sync (for example `34427469792@N01`).
- **`category`**: one category id for all synced photos (must match `content_categories.id`; default `flickr`).
- **`perPollLimit`**: maximum new photos downloaded per collect cycle (default `20`).
- **`sort`**: Flickr pool sort mode passed through to the API (default `date-posted-desc`).

**Image URL fallback:** provider prefers `url_o`, then `url_l`, `url_c`, `url_z`, `url_m`.

**Screens:** use **`pexels_photo`** (or collage widgets); set **`config.categoryId`** to the same slug as **`category`** (default **`flickr`**) so the curator pool includes downloaded Flickr rows.

**`integrations.poll_seconds`:** default **3600** when seeded.

**Debug `.env`:** **`WADDLE_DISPLAY_FLICKR_API_KEY`** (see [`.env.example`](.env.example)).

## Bing image of the day

The **Bing image of the day** provider (`id` / `provider_type`: **`media_bing_iotd`**) calls Bing’s **`HPImageArchive.aspx`** (`format=js`, `idx=0`, `n=1`, `mkt` from config), then downloads the wallpaper at **`{baseUrl}{urlbase}_{resolution}.jpg`** (same URL pattern as [TimothyYe/bing-wallpaper](https://github.com/TimothyYe/bing-wallpaper)). Image bytes go to the blob store; **`photos`** rows use **`data_provider`** = **`media_bing_iotd`**. **No API key** or SecretStore entry.

**`integrations.base_url`:** default **`https://www.bing.com`**.

**`integrations.config_json`** (JSON):

- **`retentionDays`**: drop **`photos`** (and blobs) older than this many **24h periods** (default **1**). **`<= 0`** disables age-based pruning.
- **`market`**: Bing **`mkt`** parameter (default **`en-US`**).
- **`resolution`**: suffix before `.jpg` — **`UHD`**, **`1920x1200`**, **`1920x1080`**, **`1366x768`**, **`1080x1920`**, **`768x1280`** (default **`UHD`**).
- **`category`**: **`content_categories.id`** for new rows (default **`bing`**).

**Screens:** use **`pexels_photo`** or **`photo_random`** with **`config.categoryId`**: **`bing`**.

Requests send a desktop **`User-Agent`** and **`Referer`** matching the Bing origin (Bing may throttle anonymous clients otherwise). Each HTTP call uses a **5s** timeout.

**`integrations.poll_seconds`:** default **3600** when seeded; provider is **enabled** by default.

## Drift codegen

After editing `packages/waddle_shared/lib/persistence/tables.dart` or `database.dart` schema:

```bash
dart run build_runner build --delete-conflicting-outputs -C packages/waddle_shared
flutter test -C packages/waddle_shared
```
