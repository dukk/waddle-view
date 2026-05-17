# Agent and contributor briefing — waddle-view

## Scope

1. **Mono-repo**: default application directory is **`apps/waddle_display/`** (underscore; Dart package **`waddle_display`**). Shared Drift schema and persistence live in **`packages/waddle_shared/`** (`waddle_shared`). Concrete HTTP collectors live in **`packages/waddle_data_providers/`** (`waddle_data_providers`; each implements `IDataProvider` for an **integration** id stored in the SQLite **`integrations`** table). The repo root **`pubspec.yaml`** defines a Pub **workspace** (`resolution: workspace` in each member); run **`flutter pub get`** from the **repository root** (or any workspace member) so dependencies resolve once. If a clone still has **`apps/waddle_view/`** or a stray **`apps/waddle-display/`** on disk (common on case-insensitive filesystems), align the tree with Git—IDE locks sometimes block renames until folders are closed. Do not edit other `apps/*` paths unless the task explicitly names them.
2. **Tests first**: add or extend a failing test before production code for new behavior.
3. **Coverage**: CI enforces a **≥ 85% line coverage floor** on `apps/waddle_display/lib/` plus `packages/waddle_shared/lib/` plus `packages/waddle_data_providers/lib/` per `apps/waddle_display/tool/coverage_check.dart` (excludes **`persistence/tables.dart`** declarative schema-only lines in either package, **generated `*.g.dart` Drift**, **`lib/main.dart`** in the display app, and **`lib/display/screen_rotator.dart`** slide-dispatch UI wiring covered indirectly via slide widget tests). The same tool uses a **90% aspirational target**: coverage between **85% and 90%** passes CI but prints a **warning** so contributors keep pushing toward the target. **Drift migration and shared-model unit tests** live under **`packages/waddle_shared/test/`** (`cd packages/waddle_shared` then `flutter test`). **Collector unit tests** also run under **`packages/waddle_data_providers/test/`** (`cd packages/waddle_data_providers` then `dart test`). Run from the app directory:
   - `flutter test --coverage` (each test is capped at **60s** via `apps/waddle_display/dart_test.yaml`; CI also sets a **12-minute** job timeout)
   - `dart run tool/coverage_check.dart --min=85 --target=90` (defaults match if you omit flags)
   - **Operator UI (`apps/waddle_controller/`)**: Vitest unit tests live beside sources as `src/**/*.test.ts` and `server/src/**/*.test.ts`. CI enforces **≥ 80%** line coverage on gated logic (`src/auth`, `src/api`, `src/storage`, `src/util/*.ts`, `src/constants`, `server/src/**` except `index.ts` / `testHelpers.ts`) via [`apps/waddle_controller/tool/coverage_check.mjs`](apps/waddle_controller/tool/coverage_check.mjs) (90% aspirational warning). UI shells (`pages/`, `layout/`, `components/`, `context/`, `App.tsx`, `main.tsx`) are excluded from the floor until covered by component tests. The optional **controller BFF** (Hono + SQLite under `apps/waddle_controller/server/`) gates SPA access when `WADDLE_CONTROLLER_AUTH_ENABLED=1`; display adoption is unchanged. From `apps/waddle_controller`: `npm run lint`, `npm run test:coverage`, `npm run coverage:check`, `npm run build:server`. Read [`.cursor/rules/waddle-controller.mdc`](.cursor/rules/waddle-controller.mdc) before large controller edits.
4. **Secrets**: never store provider passwords, API keys, access/refresh tokens, or client secrets in SQLite. **Static provider API keys** and display runtime config use **`WADDLE_DISPLAY_*` environment variable names** (see [`apps/waddle_display/.env.example`](apps/waddle_display/.env.example), [`apps/waddle_display/lib/config/display_env.dart`](apps/waddle_display/lib/config/display_env.dart), and [`packages/waddle_shared/lib/config/provider_access_token_env.dart`](packages/waddle_shared/lib/config/provider_access_token_env.dart)); values are read from the process environment (and merged debug `.env`). **Google and Microsoft Graph OAuth access/refresh tokens** use `SecretStore` / `flutter_secure_storage` only (not environment variables). **Google / Microsoft Graph OAuth public client ids** use **`WADDLE_DISPLAY_GOOGLE_CLIENT_ID`** and **`WADDLE_DISPLAY_MICROSOFT_GRAPH_CLIENT_ID`** in the environment — not `config_key_values`. **Display instance ids** (`waddle_instance.id` / `/etc/waddle-view/instance.id`) are filesystem HMAC secrets for the adoption API — not bearer tokens. **Adopted REST clients** store only **SHA-256 hashes** of derived API keys in SQLite (`api_clients`); plaintext keys are returned once from `POST /v1/adoption/confirm`.
5. **Project rules**: read [`.cursor/rules/waddle-view-flutter.mdc`](.cursor/rules/waddle-view-flutter.mdc) before large display edits and [`.cursor/rules/waddle-controller.mdc`](.cursor/rules/waddle-controller.mdc) before large controller edits. For git push failures or pre-push hook work, read [`.cursor/rules/waddle-prepush.mdc`](.cursor/rules/waddle-prepush.mdc).
6. **Sub-agents / delegated tasks**: include explicit **paths**, **deliverable**, and **forbidden paths** in the prompt.
7. **Documentation freshness**: when behavior, configuration, env vars, public endpoints, or operator workflows change, update the corresponding docs in the same task (for example `apps/waddle_display/README.md`, `.env.example`, and runbooks) or explain why no doc change is needed.
8. **Drift migration discipline**: for any schema/data-shape change in **`packages/waddle_shared/lib/persistence/`**, add/update migration logic and tests in the same task; do not land schema-affecting changes without a migration path and validation coverage.

## Commands (from repo root)

```bash
flutter pub get
cd packages/waddle_shared
dart run build_runner build --delete-conflicting-outputs
flutter test
cd ../waddle_data_providers
dart test
cd ../../apps/waddle_display
flutter analyze
flutter test --coverage
dart run tool/coverage_check.dart --min=85 --target=90
cd ../waddle_controller
npm ci
npm run lint
npm run test:coverage
npm run coverage:check
npm run build:server
```

## Git pre-push (local)

With [`core.hooksPath=.githooks`](scripts/install-git-hooks.sh), **`git push`** runs [`scripts/pre_push_checks.py`](scripts/pre_push_checks.py) (scoped by changed paths). It does **not** run **`npm ci`** for `apps/waddle_controller/` — a running **`npm run dev`** locks native modules on Windows and caused recurring **`EPERM`** during `npm ci`. Pre-push only runs controller **`npm run build`** and **`npm run lint`**; **CI** runs **`npm ci`** on a clean runner. After changing controller `package.json` / lockfile: stop dev, run **`npm ci`** manually, then use [`run-waddle-checks`](.cursor/skills/run-waddle-checks/SKILL.md) for the full gate. Details: [`.cursor/rules/waddle-prepush.mdc`](.cursor/rules/waddle-prepush.mdc).

## Before committing

Run the [`run-waddle-checks`](.cursor/skills/run-waddle-checks/SKILL.md) skill (or the commands above). CI's `flutter analyze` step fails on **any** issue — **warnings count** — and `flutter test` runs the full suite, including drift migration tests. Recurring regressions to check for before pushing:

1. **`drift` + `flutter_test` import ambiguity**: both libraries export `isNull`/`isNotNull`. Use `show Value` or `hide isNull, isNotNull` on the drift import.
2. **Test-fake constructor/field sync**: keep test helper constructors and fields aligned. For test-only defaults, prefer initializing the field inline (`final String folderId = 'folder1';`) over default-valued optional parameters that no caller overrides (avoids `final_not_initialized_constructor` and `unused_element_parameter`).
3. **Drift migration tests must seed legacy tables that any later migration reads** — the v27 `screens` rewrite reads the legacy `layout_json` shape from table **`screen_definitions`**, so every snapshot test below v27 needs `stubLegacyScreenDefinitionsForMigration` (alongside the existing content-categories / calendar-events stubs).
4. **`db.customStatement(sql, args)` only accepts raw values** (`null`, `bool`, `int`, `num`, `String`, `List<int>`); never pass `Variable<T>` — that's typed-builder territory.
5. **`calendar_events.category_id` is a foreign key to `content_categories.id`** with FKs on. Tests that drive calendar providers with `category` / `defaultCategory` must seed those ids first via `seedContentCategoriesForTest(db, [...])`.
6. **Every new `materialIconName` in `kContentCategoryDefaults`** (in `packages/waddle_shared/lib/persistence/content_category_defaults.dart`) needs a matching `case` in **`contentCategoryMaterialIcon`** — the dedicated test enforces this and is easy to miss when adding categories.
7. **Display-time `BlobStore.readBytes` must not throw**: slide UI and preload paths use [`readDisplayBlobBytes`](packages/waddle_shared/lib/blob/display_blob_read.dart) (see [`.cursor/rules/waddle-view-flutter.mdc`](.cursor/rules/waddle-view-flutter.mdc)); uncaught `FileSystemException` from missing blob files triggers kiosk process restart.
8. **`waddle_controller` + `npm ci` on Windows**: stop **`npm run dev`** before **`npm ci`** (Vite/tsx lock `node_modules` natives → **`EPERM`**). Pre-push never runs **`npm ci`**; run it manually after lockfile changes. See [`.cursor/rules/waddle-prepush.mdc`](.cursor/rules/waddle-prepush.mdc).

See [`.cursor/rules/waddle-view-tests.mdc`](.cursor/rules/waddle-view-tests.mdc) for the full list including Dart 3 null-promotion rules.

## Persistence

The app uses **Drift** with **`sqlite3`** / **`sqlite3_flutter_libs`** and a file-backed database from `path_provider` ([`createQueryExecutor`](apps/waddle_display/lib/persistence/flutter_query_executor.dart) in the display app) or in-memory SQLite in tests. Shared schema and [`AppDatabase`](packages/waddle_shared/lib/persistence/database.dart) live in **`waddle_shared`**.
