import type { RJSFSchema, UiSchema } from '@rjsf/utils';

type JsonSchemaObject = Record<string, unknown>;

function asObject(v: unknown): JsonSchemaObject | null {
  return v !== null && typeof v === 'object' && !Array.isArray(v) ? (v as JsonSchemaObject) : null;
}

export function schemaPropertyUsesSlider(prop: JsonSchemaObject): boolean {
  if (prop['x-waddle-widget'] === 'slider') return true;
  const t = prop.type;
  if (t !== 'integer' && t !== 'number') return false;
  return typeof prop.minimum === 'number' && typeof prop.maximum === 'number';
}

export function schemaPropertyUsesBlobKey(prop: JsonSchemaObject): boolean {
  if (prop.format === 'waddle-overlay-blob-key') return true;
  const items = asObject(prop.items);
  return items?.format === 'waddle-overlay-blob-key';
}

export function schemaPropertyIsBoolean(prop: JsonSchemaObject): boolean {
  return prop.type === 'boolean';
}

/** Builds RJSF uiSchema with switches, sliders, and blob upload fields from JSON Schema. */
export function buildUiSchemaFromJsonSchema(schema: RJSFSchema, base: UiSchema = {}): UiSchema {
  const root = asObject(schema);
  if (!root) return base;
  const properties = asObject(root.properties);
  if (!properties) return base;

  const ui: UiSchema = { ...base };
  for (const [key, rawProp] of Object.entries(properties)) {
    const prop = asObject(rawProp);
    if (!prop) continue;
    const fieldUi: Record<string, unknown> = {};
    if (schemaPropertyIsBoolean(prop)) {
      fieldUi['ui:widget'] = 'WaddleSwitchWidget';
    } else if (schemaPropertyUsesSlider(prop)) {
      fieldUi['ui:widget'] = 'WaddleSliderWidget';
    } else if (schemaPropertyUsesBlobKey(prop)) {
      fieldUi['ui:field'] = 'OverlayBlobKeysField';
    }
    if (Object.keys(fieldUi).length > 0) {
      ui[key] = fieldUi;
    }
  }
  return ui;
}
