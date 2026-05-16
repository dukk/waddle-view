---
name: run-waddle-checks
description: >-
  Runs the full local CI-equivalent check sequence for waddle_display
  (pub get, codegen, analyze, test+coverage, coverage gate) and optionally
  waddle_controller (lint, vitest coverage, coverage gate, build). Use before
  committing changes under apps/waddle_display/ or apps/waddle_controller/ or
  when diagnosing CI failures.
disable-model-invocation: true
---

# Run waddle_display CI checks locally

Mirror of [`.github/workflows/ci.yml`](../../../.github/workflows/ci.yml) `analyze-test` job. CI fails on **any** `flutter analyze` issue (warnings included) and on coverage **below 85%** (the **90%** line is a target: the checker warns but does not fail between 85% and 90%), so run the same commands locally before pushing.

## Commands (from repo root)

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs -C packages/waddle_shared
flutter test -C packages/waddle_shared
cd apps/waddle_display
flutter analyze
flutter test --coverage --timeout=60s
dart run tool/coverage_check.dart --min=85 --target=90 coverage/lcov.info
```

## Notes

- `flutter analyze` must report **zero** issues; warnings are fatal in CI.
- Each test is capped at 60s by [`dart_test.yaml`](../../../apps/waddle_display/dart_test.yaml); the CI job has a 12-minute wall budget.
- For the recurring test-file pitfalls (drift/`flutter_test` import ambiguity, orphaned `final` fields, redundant `!` after promotion), see [`waddle-view-tests.mdc`](../../../.cursor/rules/waddle-view-tests.mdc).
- Coverage exclusions and broader contributor guidance live in [`AGENTS.md`](../../../AGENTS.md) and [`waddle-view-flutter.mdc`](../../../.cursor/rules/waddle-view-flutter.mdc).

## waddle_controller (when that app changed)

```bash
cd apps/waddle_controller
npm ci
npm run lint
npm run test:coverage
npm run coverage:check
npm run build
```

See [`waddle-controller.mdc`](../../../.cursor/rules/waddle-controller.mdc).
