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

- **Use [`SchemaConfigForm`](../../../apps/waddle_controller/src/components/config/SchemaConfigForm.tsx)** for operator `config_json` editing when the shape is documented in [`config_json_documentation.dart`](../../../packages/waddle_shared/lib/persistence/config_json_documentation.dart) (or a meta endpoint returns `config_json_schema` + `example_config_json`).
- **Do not** use for one-off composite UIs (Outlook calendar section, adoption flows) — keep bespoke sections there.

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
4. Expose built-in overlay types via `kBuiltinOverlayTypes` and `GET /v1/meta/overlay-types`.

## Canonical usage

- **Overlays**: [`OverlaysPage.tsx`](../../../apps/waddle_controller/src/pages/OverlaysPage.tsx) loads `/v1/meta/overlay-types`, renders name + type + `SchemaConfigForm` in the edit dialog.
- **Integrations / screens**: may still use raw `@rjsf/mui` `Form`; prefer migrating to `SchemaConfigForm` when touching those pages.

## Verification

```bash
cd apps/waddle_controller
npm run lint
npm run test:coverage -- src/util/schemaConfigForm.test.ts
```

For overlay persistence changes, also run `flutter test` under `packages/waddle_shared` and `apps/waddle_display`.
