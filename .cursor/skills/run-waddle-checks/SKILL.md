---
name: run-waddle-checks
description: >-
  Runs the full local CI-equivalent check sequence for waddle_display
  (pub get, codegen, analyze, test+coverage, coverage gate) and optionally
  waddle_controller (npm ci, lint, vitest coverage, coverage gate, build).
  Use before committing or when diagnosing CI failures. Git pre-push does NOT
  run npm ci for waddle_controller (see waddle-prepush.mdc).
disable-model-invocation: true
---

# Run waddle_display CI checks locally

Mirror of [`.github/workflows/ci.yml`](../../../.github/workflows/ci.yml) `analyze-test` job. CI fails on **any** `flutter analyze` issue (warnings included) and on coverage **below 80%** on gated libs (display, shared, data_providers, plugin_sdk; **not** `waddle_plugin_example`). The **90%** line is a target: the checker warns but does not fail between 80% and 90%.

## Tiered script (recommended)

From repo root:

```bash
# Inner loop: analyze only (or --from-git / --test for scoped runs)
python scripts/waddle_checks.py fast

# Git-scoped packages + mapped tests; skips pub get/codegen when unchanged
python scripts/waddle_checks.py fast --from-git

# Single display test file
python scripts/waddle_checks.py fast --test apps/waddle_display/test/util/html_entity_decode_test.dart

# CI parity (coverage + optional controller)
python scripts/waddle_checks.py full
python scripts/waddle_checks.py full --controller
```

Environment overrides:

- `WADDLE_TEST_CONCURRENCY` — `flutter test` / `dart test` workers (default `min(4, cpu_count)`).
- `WADDLE_CHECKS_PARALLEL_ANALYZE=0` — disable parallel `flutter analyze` + display tests (default on).

Pre-push ([`scripts/pre_push_checks.py`](../../../scripts/pre_push_checks.py)) uses the same fast optimizations (no coverage, conditional `pub get` / `build_runner`, test concurrency) but always runs the **full** Dart test suites for each workspace package in scope.

## Full commands (manual CI mirror)

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs -C packages/waddle_shared
flutter test -C packages/waddle_shared
cd apps/waddle_display
flutter analyze
flutter test --coverage --timeout=60s
dart run tool/coverage_check.dart --min=80 --target=90 coverage/lcov.info ../../packages/waddle_plugin_sdk/coverage/lcov.info
```

## Notes

- `flutter analyze` must report **zero** issues; warnings are fatal in CI.
- Each test is capped at 60s by [`dart_test.yaml`](../../../apps/waddle_display/dart_test.yaml); the CI job has a 12-minute wall budget.
- For the recurring test-file pitfalls (drift/`flutter_test` import ambiguity, orphaned `final` fields, redundant `!` after promotion), see [`waddle-view-tests.mdc`](../../../.cursor/rules/waddle-view-tests.mdc).
- Coverage exclusions and broader contributor guidance live in [`AGENTS.md`](../../../AGENTS.md) and [`waddle-view-flutter.mdc`](../../../.cursor/rules/waddle-view-flutter.mdc).

## waddle_controller (when that app changed)

Full mirror of CI `analyze-test` for the controller (includes **`npm ci`**). **Git pre-push does not run `npm ci`** — only `build` + `lint` — so dev (`npm run dev`) does not block push with Windows `EPERM`. Run this block manually before merge-quality pushes and after lockfile changes.

```bash
cd apps/waddle_controller
# Stop npm run dev first on Windows (Vite/tsx lock node_modules natives).
npm ci
npm run lint
npm run test:coverage
npm run coverage:check
npm run build
npm run build:server
```

- **`npm ci`**: required locally after `package.json` / `package-lock.json` changes; stop **`npm run dev`** first on Windows.
- **Pre-push only**: `npm run build` && `npm run lint` (see [`waddle-prepush.mdc`](../../../.cursor/rules/waddle-prepush.mdc)).
- **Node version**: package expects **Node ^22**; CI uses 22.x (Node 24 may warn).

See [`waddle-controller.mdc`](../../../.cursor/rules/waddle-controller.mdc).
