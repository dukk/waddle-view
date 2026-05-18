import { describe, expect, it } from 'vitest';
import {
  buildUiSchemaFromJsonSchema,
  schemaPropertyIsBoolean,
  schemaPropertyUsesBlobKey,
  schemaPropertyUsesSlider,
} from './schemaConfigForm';

describe('schemaConfigForm', () => {
  it('detects slider properties', () => {
    expect(
      schemaPropertyUsesSlider({
        type: 'number',
        minimum: 0,
        maximum: 1,
        'x-waddle-widget': 'slider',
      }),
    ).toBe(true);
    expect(
      schemaPropertyUsesSlider({ type: 'integer', minimum: 8, maximum: 120 }),
    ).toBe(true);
    expect(schemaPropertyUsesSlider({ type: 'string' })).toBe(false);
  });

  it('detects blob key properties', () => {
    expect(
      schemaPropertyUsesBlobKey({
        type: 'array',
        items: { type: 'string', format: 'waddle-overlay-blob-key' },
      }),
    ).toBe(true);
  });

  it('detects boolean properties', () => {
    expect(schemaPropertyIsBoolean({ type: 'boolean' })).toBe(true);
  });

  it('buildUiSchemaFromJsonSchema maps widgets and fields', () => {
    const ui = buildUiSchemaFromJsonSchema({
      type: 'object',
      properties: {
        shadow: { type: 'boolean' },
        density: { type: 'number', minimum: 0.1, maximum: 0.9 },
        image_blob_keys: {
          type: 'array',
          items: { type: 'string', format: 'waddle-overlay-blob-key' },
        },
      },
    });
    expect(ui.shadow).toEqual({ 'ui:widget': 'WaddleSwitchWidget' });
    expect(ui.density).toEqual({ 'ui:widget': 'WaddleSliderWidget' });
    expect(ui.image_blob_keys).toEqual({ 'ui:field': 'OverlayBlobKeysField' });
  });
});
