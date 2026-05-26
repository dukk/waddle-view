---
name: general-openai-kv-display
description: >-
  Configure general_openai integrations, author prompts whose JSON matches KV
  value schemas, and build general_* screens with kv_* widgets. Use when adding
  or editing OpenAI scheduled dashboards, prompt output shapes, or KV-bound
  slide widgets.
disable-model-invocation: true
---

# General OpenAI + KV dashboards

## Architecture

1. **`general_openai` collector** (`packages/waddle_integrations/lib/general_openai/`) runs prompts on `pollSeconds`, calls OpenAI **Responses API** (`POST /v1/responses`), optional remote HTTP **MCP** tools, and writes:
   - `prompt.{promptId}.latest`: upserted latest payload
   - `prompt.{promptId}.history.{collectedAtMs}`: immutable history rows
   - `prompt.{promptId}.last_collect_ms`: poll gate
2. **`general_*` screens** (`general_full_screen`, `general_2_column`, `general_3_column`, `general_2x2`, `general_3x2`) store a `slots[]` array in `screens.config_json`. Runtime [synthesizeLayoutJson](packages/waddle_shared/lib/layout/screen_layout_parse.dart) flattens slots into layout JSON consumed by [GeneralLayoutSlideWidget](apps/waddle_display/lib/display/screens/general_layout/general_layout_slide_widget.dart).
3. **`kv_*` widgets** read `integrationId` + `valueKey` (+ optional `jsonPath`) via [integration_kv_read.dart](packages/waddle_shared/lib/integrations/integration_kv_read.dart).

## Schema sources

| Layer | Dart catalog | REST |
|-------|----------------|------|
| Integration config | `kProviderConfigJsonMeta['general_openai']` | `GET /v1/meta/config-schemas` → `integration_types` |
| Screen layout | `screenConfigJsonDocForType('general_*')` | `screen_types` |
| Widget config | [kv_schema_documentation.dart](packages/waddle_shared/lib/persistence/kv_schema_documentation.dart) → `kKvWidgetConfigJsonMeta` | `kv_widget_types` |
| KV value shape | `kKvValueDataTypeMeta` | `kv_value_data_types` |

Each widget config schema includes `x-waddle-value-type` pointing at a value data type id.

## Widget → value type matrix

| Widget | `expectedValueType` | Prompt hint |
|--------|---------------------|-------------|
| `kv_list` | `list_string_array` | Return `["item", ...]` or `{"items":[...]}` |
| `kv_table` | `table_rows` | Return `[{"col": value}, ...]` |
| `kv_chart` | `chart_series` | Return `[{"x":"Mon","y":12}, ...]` or `{"series":[...]}` |
| `kv_gauge` | `gauge_scalar` | Return `42` or `{"value":72,"max":100}` |
| `kv_graph` | `graph_adjacency` | Return `{"nodes":[...],"edges":[...]}` |
| `kv_image` | `image_url` | Return `{"url":"https://..."}` |
| `kv_shape` | `shape_style` | Return `{"shape":"circle","color":"#ff6600"}` |

Set `responseFormat: json_object` on prompts when widgets need structured JSON. Align `userPrompt` / `systemPrompt` with the target `kv_value_data_types` example from the meta bundle.

## MCP (remote HTTP only)

Per-prompt `mcpServers[]` maps to Responses API MCP tools. Authorization:

- Default secret key: `provider:mcp:{integrationId}:{serverLabel}:authorization` via [SecretStore](packages/waddle_shared/lib/secrets/secret_store.dart)
- Or `authorizationSecretKey` in config → `provider:mcp:{integrationId}:{customKey}`

## Operator debugging

- `GET /v1/integrations/{id}/kv?prefix=prompt.`: list keys (metadata only)
- `GET /v1/integrations/{id}/kv/{key}`: read value
- `DELETE /v1/integrations/{id}/kv/{key}`: purge one key

## Checklist (new widget or screen)

1. Add `kKvWidgetConfigJsonMeta` + `kKvValueDataTypeMeta` entries in [kv_schema_documentation.dart](packages/waddle_shared/lib/persistence/kv_schema_documentation.dart).
2. Implement slide widget under `apps/waddle_display/lib/display/screens/kv/`.
3. Register `case` in [screen_widget_registry.dart](apps/waddle_display/lib/extensions/screen_widget_registry.dart).
4. Extend [kv_schema_documentation_test.dart](packages/waddle_shared/test/persistence/kv_schema_documentation_test.dart).
5. Update this skill's matrix.

## Related skills

- [add-provider](add-provider/SKILL.md): new collectors
- [add-display-screen](add-display-screen/SKILL.md): standalone screen types (not `kv_*` children)
- [schema-config-form](schema-config-form/SKILL.md): controller RJSF forms
