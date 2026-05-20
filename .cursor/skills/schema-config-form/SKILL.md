---
name: schema-config-form
description: >-
  Build uniform JSON Schema-driven config forms in waddle_controller using
  SchemaConfigForm (switches, sliders, overlay blob uploads). Use when adding
  or editing config_json UIs for overlays, integrations, screens, or similar
  catalog entities backed by displayOverlayConfigJsonDocForType / RJSF.
disable-model-invocation: true
---

# Schema-driven config forms (waddle_controller)

## When to use

- **Use [`SchemaConfigForm`](../../../apps/waddle_controller/src/components/config/SchemaConfigForm.tsx)** for operator `config_json` editing when the shape is documented in [`config_json_documentation.dart`](../../../packages/waddle_shared/lib/persistence/config_json_documentation.dart). The controller loads **type-level** `config_json_schema` from SQLite **`overlay_types`** via `GET /v1/meta/config-schemas` → `overlay_types`, cached in [`configSchemaCache.ts`](../../../apps/waddle_controller/src/storage/configSchemaCache.ts) (not on every catalog page refresh). New built-in overlay types require DB sync (`ensureOverlayTypes`) plus a cache prefix bump — see [add-display-overlay](../add-display-overlay/SKILL.md).
- For a **new built-in overlay type** end-to-end (registry, widget, normalize, icons), use [add-display-overlay](../add-display-overlay/SKILL.md) — this skill covers schema-driven form controls only.
- **Do not** use for one-off composite UIs (Outlook calendar section, adoption flows) — keep bespoke sections there.
- Inside a dialog that saves via API, pass **`disabled={saving}`** (or `busy`) while submit is in-flight — see [controller-dialog-submit](../controller-dialog-submit/SKILL.md).

## JSON Schema → control mapping

| Schema signal | UI control | Notes |
|---------------|------------|--------|
| `type: boolean` | MUI `Switch` via `WaddleSwitchWidget` | Auto via [`buildUiSchemaFromJsonSchema`](../../../apps/waddle_controller/src/util/schemaConfigForm.ts) |
| `type: integer` / `number` with `minimum` + `maximum` | MUI `Slider` via `WaddleSliderWidget` | Also when `x-waddle-widget: slider` is set |
| `format: waddle-overlay-blob-key` on `items` (array) | `OverlayBlobKeysField` | Upload via `POST /v1/display/overlays/blobs`; stores `image_blob_keys` |
| `enum` | RJSF default select | No custom widget |
| Plain `string` / `array` of strings | RJSF defaults | e.g. `messages` phrase lists |

Helpers live in [`schemaConfigForm.ts`](../../../apps/waddle_controller/src/util/schemaConfigForm.ts) (unit-tested).

## Extending schemas (Dart)

1. Add or update `displayOverlayConfigJsonDocForType` / `screenConfigJsonDocForType` in [`config_json_documentation.dart`](../../../packages/waddle_shared/lib/persistence/config_json_documentation.dart).
2. For sliders, include `minimum`, `maximum`, and optionally `'x-waddle-widget': 'slider'`.
3. For overlay image pools, use array `items: { format: 'waddle-overlay-blob-key', ... }`.
4. Add the type to `kBuiltinOverlayTypes` and ensure [`ensureOverlayTypes`](../../../packages/waddle_shared/lib/seed/tables/overlay_types_seed.dart) inserts/updates the **`overlay_types`** row (runs before `buildOverlayTypeConfigJsonMetaItemsFromDb` serves `GET /v1/meta/config-schemas`). Do not rely on a code-only catalog at API read time.

## Canonical usage

- **Overlays**: [`OverlaysPage.tsx`](../../../apps/waddle_controller/src/pages/OverlaysPage.tsx) reads cached overlay type schemas from [`useConfigSchemas`](../../../apps/waddle_controller/src/hooks/useConfigSchemas.ts), renders name + type + `SchemaConfigForm` in the edit dialog.
- **Integrations / screens**: may still use raw `@rjsf/mui` `Form`; prefer migrating to `SchemaConfigForm` when touching those pages.

## Verification

```bash
cd apps/waddle_controller
npm run lint
npm run test:coverage -- src/util/schemaConfigForm.test.ts
```

For overlay persistence changes, also run `flutter test` under `packages/waddle_shared` and `apps/waddle_display`.
