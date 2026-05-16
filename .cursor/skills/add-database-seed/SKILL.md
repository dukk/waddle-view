---
name: add-database-seed
description: >-
  Adds or updates idempotent initial SQLite seed data for waddle-display
  (ensureInitialSeed, seed tables, tests). Use when seeding defaults, demo rows,
  or first-run configuration—not for secrets.
disable-model-invocation: true
---

# Add database seed data

Repo constraints: [AGENTS.md](../../../AGENTS.md) (default app **`apps/waddle_display/`** only; tests-first; ≥90% line coverage; **never** store provider passwords, API keys, tokens, or client secrets in SQLite—use [`SecretStore`](../../../apps/waddle_display/lib/secrets/); any schema change under `lib/persistence/` needs a **Drift migration + tests** in the same task).

## Forbidden

- Do not edit other `apps/*` packages unless the task explicitly names them.
- Do not commit deployment REST API keys; document file paths only.

## Checklist

1. **Entry point** — Implement idempotent logic in [`ensureInitialSeed`](../../../apps/waddle_display/lib/seed/initial_seed.dart) or a helper it calls. Prefer `insertOnConflictUpdate` or a select-then-insert pattern like existing `_ensure*` functions.
2. **Factoring** — For non-trivial table-specific seeding, add `apps/waddle_display/lib/seed/tables/<name>_seed.dart` and call it from `ensureInitialSeed` (see [`content_categories_seed.dart`](../../../apps/waddle_display/lib/seed/tables/content_categories_seed.dart)).
3. **Integration rows** — When inserting into `integrations`, use [`providerConfigJsonDocForType`](../../../packages/waddle_shared/lib/persistence/config_json_documentation.dart) for `configJsonSchema` / `exampleConfigJson` where applicable.
4. **Screens / tickers** — Reuse patterns in `initial_seed.dart` for `screen_definitions` and `ticker_definitions` (avoid duplicating the same seed logic in two files).
5. **Persistence migrations** — If adding columns or tables, update Drift schema + migration steps under `apps/waddle_display/lib/persistence/` and add validation tests per project rules.
6. **Tests** — Add tests under `apps/waddle_display/test/seed/` proving rows exist, counts, and **idempotency** (second `ensureInitialSeed` does not duplicate or break data). Model after [`initial_seed_test.dart`](../../../apps/waddle_display/test/seed/initial_seed_test.dart).
7. **Docs** — If first-run or operator-visible defaults change, update `README.md`, `.env.example`, or runbooks in the same change set.

## Canonical example

- [`ensureInitialSeed`](../../../apps/waddle_display/lib/seed/initial_seed.dart) stub + provider rows + `_ensureTickerDefinitions` pattern; tests in [`test/seed/initial_seed_test.dart`](../../../apps/waddle_display/test/seed/initial_seed_test.dart).

## Verification

From `apps/waddle_display`: `flutter analyze`, `flutter test test/seed/`, `flutter test --coverage`, `dart run tool/coverage_check.dart --min=90`.
