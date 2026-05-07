---
name: add-ticker-marquee-type
description: >-
  Adds a new ticker_definitions tickerType and marquee curation branch in
  waddle-display. Use when extending the bottom marquee, ticker slots, or
  TickerItem kinds from config/KV data.
disable-model-invocation: true
---

# Add ticker marquee type

Repo constraints: [AGENTS.md](../../../AGENTS.md) (default app **`apps/waddle-display/`** only; tests-first; ≥90% line coverage on `lib/`; no secrets in marquee bodies—respect redaction rules).

## Forbidden

- Do not edit other `apps/*` packages unless the task explicitly names them.

## Checklist

1. **Curation** — Extend [`ticker_curation.dart`](../../../apps/waddle-display/lib/curator/ticker_curation.dart): add an `expand…()` (or equivalent) and a `case` in `itemsForDef` for the new `tickerType` string. Reuse existing dedup (`seenBodies`) and [`redactTickerBody`](../../../apps/waddle-display/lib/curator/ticker_curation.dart) behavior; do not log or persist raw secrets in marquee text.
2. **KV / config keys** — If the ticker reads copy from `config_key_values`, document the key convention (existing pattern: `ticker.marquee.*`). Align with how [`DefaultDashboardCurator`](../../../apps/waddle-display/lib/curator/default_dashboard_curator.dart) supplies KV to curation.
3. **Seed definitions** — Add or update rows in `ticker_definitions` idempotently. **Single source of truth:** either call [`ensureTickerDefinitionsSeed`](../../../apps/waddle-display/lib/seed/tables/ticker_definitions_seed.dart) from [`ensureInitialSeed`](../../../apps/waddle-display/lib/seed/initial_seed.dart) **or** extend `_ensureTickerDefinitions` in `initial_seed.dart`—do not maintain two divergent copies of the same rows.
4. **Tests** — Add or extend tests under `apps/waddle-display/test/curator/` (or focused unit tests) for the new branch and for seed idempotency if seed data changed (see [`test/seed/initial_seed_test.dart`](../../../apps/waddle-display/test/seed/initial_seed_test.dart) for ticker definition expectations).

## Canonical examples

- Definition-driven expansion: `itemsForDef` / `expandStocks` in [`ticker_curation.dart`](../../../apps/waddle-display/lib/curator/ticker_curation.dart).
- Seed shape: [`ticker_definitions_seed.dart`](../../../apps/waddle-display/lib/seed/tables/ticker_definitions_seed.dart) (ensure it stays wired if used).

## Verification

From `apps/waddle-display`: `flutter analyze`, `flutter test --coverage`, `dart run tool/coverage_check.dart --min=90`.
