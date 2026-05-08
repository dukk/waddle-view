---
name: add-display-screen
description: >-
  Adds a new display slide widget type to waddle-display (layout JSON type,
  ScreenRotator dispatch, schema). Use when creating a new screen layout widget,
  slide type, or display/ UI surface driven by screen_definitions.
disable-model-invocation: true
---

# Add display screen (slide widget type)

Repo constraints: [AGENTS.md](../../../AGENTS.md) (default app **`apps/waddle_display/`** only; tests-first; ≥90% line coverage on `lib/`; update docs when operator-facing behavior changes; Drift migrations if persistence shape changes).

## Forbidden

- Do not edit other `apps/*` packages unless the task explicitly names them.

## Checklist

1. **Widget** — Add `*SlideWidget` (and supporting types) under `apps/waddle_display/lib/display/screens/<feature>/`.
2. **Dispatch** — Add a `case '<type>':` branch in [`screen_rotator.dart`](../../../apps/waddle_display/lib/display/screen_rotator.dart) and the matching import at the top of that file.
3. **Layout contract** — Append the same `type` string to [`kScreenLayoutWidgetTypes`](../../../apps/waddle_display/lib/persistence/config_json_documentation.dart) and extend [`kScreenLayoutJsonSchema`](../../../apps/waddle_display/lib/persistence/config_json_documentation.dart) so admin/validation accept the new widget.
4. **Parsing** — If the widget needs per-type defaults (e.g. RSS-style capacity hints), update [`screen_layout_parse.dart`](../../../apps/waddle_display/lib/curator/screen_layout_parse.dart).
5. **Data key** — If the slide needs curated content from a provider, set `dataKey` on the `screen_definitions` row to match the provider / pool contract (see [`screen_program_curator.dart`](../../../apps/waddle_display/lib/curator/screen_program_curator.dart)).
6. **Optional seed** — Add an idempotent `_ensure…Screen` in [`initial_seed.dart`](../../../apps/waddle_display/lib/seed/initial_seed.dart) inserting into `screen_definitions` with valid `layoutJson`, `layoutJsonSchema`, and `exampleLayoutJson` (copy patterns from existing `_ensureJokeScreen`-style helpers).
7. **Tests** — Add widget tests under `apps/waddle_display/test/` mirroring `lib/` (e.g. `test/display/...`). [`screen_rotator.dart`](../../../apps/waddle_display/lib/display/screen_rotator.dart) slide wiring may be covered indirectly via slide widget tests per AGENTS.md exclusions—prefer direct tests for new widget logic.

## Canonical example

- [`WeatherSlideWidget`](../../../apps/waddle_display/lib/display/screens/weather/weather_slide_widget.dart) + `weather` cases in [`screen_rotator.dart`](../../../apps/waddle_display/lib/display/screen_rotator.dart).

## Verification

From `apps/waddle_display`: `flutter analyze`, `flutter test --coverage`, `dart run tool/coverage_check.dart --min=90`.
