---
name: add-provider
description: >-
  Adds a new IDataProvider to waddle-display (collect loop, config schema,
  composition). Use when implementing or wiring a data provider, ingestion
  source, or DataCollectionEngine provider.
disable-model-invocation: true
---

# Add IDataProvider (waddle-display)

Repo constraints: [AGENTS.md](../../../AGENTS.md) (default app **`apps/waddle_display/`** only; tests-first; ≥90% line coverage on `lib/`; no secrets in SQLite; Drift migrations if persistence changes).

## Forbidden

- Do not edit other `apps/*` packages unless the task explicitly names them.

## Checklist

1. **Interface** — Implement [`IDataProvider`](../../../apps/waddle_display/lib/data/data_provider.dart) (`String get id`, `Future<void> collect(DataWriteContext ctx)`) in `apps/waddle_display/lib/data/providers/<provider_id>/` (one folder per provider; shared code in `providers/shared/` or e.g. `providers/microsoft_graph/`).
2. **Config metadata** — If the provider appears in admin/settings JSON, add `providerType` to [`kProviderConfigJsonMeta`](../../../packages/waddle_shared/lib/persistence/config_json_documentation.dart) / use [`providerConfigJsonDocForType`](../../../packages/waddle_shared/lib/persistence/config_json_documentation.dart) for `integrations` rows seeded in [`ensureInitialSeed`](../../../packages/waddle_shared/lib/seed/initial_seed.dart) when needed.
3. **Composition** — Register an instance in the `DataCollectionEngine` `providers:` list in [`main.dart`](../../../apps/waddle_display/lib/main.dart).
4. **Screens / curator** — If slides read this data, align [`ScreenDefinitions.dataKey`](../../../apps/waddle_display/lib/persistence/tables.dart) and curator behavior with provider `id` / content pools (see [`screen_program_curator.dart`](../../../apps/waddle_display/lib/curator/screen_program_curator.dart)).
5. **Secrets** — API keys, tokens, and client secrets go through [`SecretStore`](../../../apps/waddle_display/lib/secrets/) / resolver / dev dotenv bootstrap — **not** `config_key_values` or other SQLite fields.
6. **Engine contract** — `collect` must be safe to call on the engine schedule; avoid overlapping work with other providers that fight the same rows unless the design explicitly allows it.
7. **Tests** — Add or extend tests under `apps/waddle_display/test/data/` using a fake `DataWriteContext` / in-memory DB patterns used by existing provider tests. Run `flutter test test/data/`.
8. **Docs** — If operator setup, env vars, or public behavior change, update `apps/waddle_display/README.md`, `.env.example`, or runbooks in the same change set.

## Canonical example

- [`JokeDataProvider`](../../../apps/waddle_display/lib/data/providers/joke/joke_data_provider.dart) — `id`, `collect`, `resolveConfig`, skip-when-disabled, persistence writes.

## Verification

From `apps/waddle_display`: `flutter analyze`, `flutter test --coverage`, `dart run tool/coverage_check.dart --min=90`.
