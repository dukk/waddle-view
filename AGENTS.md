# Agent and contributor briefing — waddle-view

## Scope

1. **Mono-repo**: default application directory is **`apps/waddle_display/`** (underscore; Dart package **`waddle_display`**). If a clone still has **`apps/waddle_view/`** or a stray **`apps/waddle-display/`** on disk (common on case-insensitive filesystems), align the tree with Git—IDE locks sometimes block renames until folders are closed. Do not edit other `apps/*` paths unless the task explicitly names them.
2. **Tests first**: add or extend a failing test before production code for new behavior.
3. **Coverage**: maintain **≥ 90% line coverage** on `apps/waddle_display/lib/` per `tool/coverage_check.dart` (excludes **`lib/persistence/tables.dart`** declarative schema-only lines, **`lib/**/*.g.dart` generated Drift**, **`lib/main.dart`** composition root, and **`lib/display/screen_rotator.dart`** slide-dispatch UI wiring covered indirectly via slide widget tests). Run from the app directory:
   - `flutter test --coverage` (each test is capped at **60s** via `apps/waddle_display/dart_test.yaml`; CI also sets a **12-minute** job timeout)
   - `dart run tool/coverage_check.dart --min=90`
4. **Secrets**: never store provider passwords, API keys, access/refresh tokens, or client secrets in SQLite. Use `SecretStore`. **Deployment REST API keys** must never be committed; only document paths (e.g. `/etc/waddle-view/api.key`).
5. **Project rules**: read [`.cursor/rules/waddle-view-flutter.mdc`](.cursor/rules/waddle-view-flutter.mdc) before large edits.
6. **Sub-agents / delegated tasks**: include explicit **paths**, **deliverable**, and **forbidden paths** in the prompt.
7. **Documentation freshness**: when behavior, configuration, env vars, public endpoints, or operator workflows change, update the corresponding docs in the same task (for example `apps/waddle_display/README.md`, `.env.example`, and runbooks) or explain why no doc change is needed.
8. **Drift migration discipline**: for any schema/data-shape change in `apps/waddle_display/lib/persistence/`, add/update migration logic and tests in the same task; do not land schema-affecting changes without a migration path and validation coverage.

## Commands (from repo root)

```bash
cd apps/waddle_display
flutter analyze
flutter test --coverage
dart run tool/coverage_check.dart --min=90
```

## Before committing

Run the [`run-waddle-checks`](.cursor/skills/run-waddle-checks/SKILL.md) skill (or the commands above). CI's `flutter analyze` step fails on **any** issue — **warnings count**. Two regressions have recurred here recently; check for both before pushing test changes:

1. **`drift` + `flutter_test` import ambiguity**: both libraries export `isNull`/`isNotNull`. Tests that import `package:drift/drift.dart` unqualified alongside `flutter_test` produce `ambiguous_import` errors. Use `show Value` (or whatever drift symbols the test needs) or `hide isNull, isNotNull`.
2. **Test-fake constructor/field sync**: keep test helper constructors and fields aligned. Removing only the parameter leaves an uninitialized `final` field (`final_not_initialized_constructor`); adding a default-valued optional parameter to a private class that no caller overrides trips `unused_element_parameter`. For test-only defaults, prefer initializing the field inline (`final String folderId = 'folder1';`) and only add a constructor parameter when a test actually overrides it.

See [`.cursor/rules/waddle-view-tests.mdc`](.cursor/rules/waddle-view-tests.mdc) for the full list including Dart 3 null-promotion rules.

## Persistence

The app uses **Drift** with **`sqlite3`** / **`sqlite3_flutter_libs`** and a file-backed database from `path_provider` (`createQueryExecutor`) or in-memory SQLite in tests.
