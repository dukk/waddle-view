---
name: add-display-screen
description: >-
  Adds a new display slide widget type to waddle-display (layout JSON type,
  ScreenRotator dispatch, schema). Use when creating a new screen layout widget,
  slide type, or display/ UI surface driven by screen_definitions.
disable-model-invocation: true
---

# Add display screen (slide widget type)

Repo constraints: [AGENTS.md](../../../AGENTS.md) (default app **`apps/waddle_display/`** only; tests-first; ≥85% line coverage on `lib/`; update docs when operator-facing behavior changes; Drift migrations if persistence shape changes).

## Forbidden

- Do not edit other `apps/*` packages unless the task explicitly names them.
- **`kv_*` widgets** are not standalone screen types — they render inside `general_*` layouts. Use [general-openai-kv-display](../general-openai-kv-display/SKILL.md) instead.

## Related skills

- [add-display-overlay](../add-display-overlay/SKILL.md) — celebration / always-on overlay types (separate from slide widgets)

## Checklist

1. **Widget** — Add `*SlideWidget` (and supporting types) under `apps/waddle_display/lib/display/screens/<feature>/`.
2. **Dispatch** — Add a `case '<type>':` branch in [`screen_widget_registry.dart`](../../../apps/waddle_display/lib/extensions/screen_widget_registry.dart) and the matching import at the top of that file (used from [`screen_rotator.dart`](../../../apps/waddle_display/lib/display/screen_rotator.dart); both are CI coverage exclusions).
3. **Layout contract** — Append the same `type` string to [`kScreenLayoutWidgetTypes`](../../../apps/waddle_display/lib/persistence/config_json_documentation.dart) and add a [`kScreenConfigJsonMeta`](../../../apps/waddle_display/lib/persistence/config_json_documentation.dart) entry (or rely on [`kGenericScreenConfigJsonDoc`](../../../apps/waddle_display/lib/persistence/config_json_documentation.dart)) so `config_json_schema` / `example_config_json` document the widget’s `config_json` shape.
4. **Parsing** — If the widget needs per-type defaults (e.g. RSS-style capacity hints), update [`screen_layout_parse.dart`](../../../apps/waddle_display/lib/curator/screen_layout_parse.dart).
4b. **Operator config** — In [`config_json_documentation.dart`](../../../packages/waddle_shared/lib/persistence/config_json_documentation.dart), use `x-waddle-enum-labels`, category **names** (`categoryName` / `categoryNames`), and widgets from [schema-config-form](../schema-config-form/SKILL.md). Bump Drift schema when renaming stored keys.
5. **Data key** — If the slide needs curated content from a provider, set `dataKey` on the `screen_definitions` row to match the provider / pool contract (see [`screen_program_curator.dart`](../../../apps/waddle_display/lib/curator/screen_program_curator.dart)).
6. **Optional seed** — Add an idempotent `_ensure…Screen` in [`initial_seed.dart`](../../../apps/waddle_display/lib/data/seed/initial_seed.dart) inserting into `screen_definitions` with `screenType`, `configJson`, `configJsonSchema`, and `exampleConfigJson` (copy patterns from existing `_ensureJokeScreen`-style helpers).
7. **Tests** — Add widget tests under `apps/waddle_display/test/` mirroring `lib/` (e.g. `test/display/...`). Registry/rotator dispatch is excluded from the CI coverage gate—prefer direct tests for new widget logic.

## Canonical example

- [`WeatherSlideWidget`](../../../apps/waddle_display/lib/display/screens/weather/weather_slide_widget.dart) + `weather` case in [`screen_widget_registry.dart`](../../../apps/waddle_display/lib/extensions/screen_widget_registry.dart).

## Verification

From `apps/waddle_display`: `flutter analyze`, `flutter test --coverage`, `dart run tool/coverage_check.dart --min=85`.
