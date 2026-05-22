import { describe, expect, it } from 'vitest';
import { normalizeSchemaFieldLabels } from './schemaFieldLabel';
import {
  buildUiSchemaFromJsonSchema,
  schemaPropertyIsBoolean,
  schemaPropertyUsesBlobKey,
  schemaPropertyUsesContentCategory,
  schemaPropertyUsesContentCategoryMulti,
  schemaPropertyUsesDuration,
  schemaPropertyUsesEnumLabels,
  schemaPropertyUsesSlider,
  schemaPropertyUsesThemeAccent,
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

  it('detects duration properties', () => {
    expect(
      schemaPropertyUsesDuration({
        type: 'integer',
        'x-waddle-widget': 'duration',
      }),
    ).toBe(true);
  });

  it('detects content category properties', () => {
    expect(
      schemaPropertyUsesContentCategory({
        type: 'string',
        'x-waddle-widget': 'content-category',
      }),
    ).toBe(true);
    expect(schemaPropertyUsesContentCategory({ type: 'string' })).toBe(false);
    expect(
      schemaPropertyUsesContentCategoryMulti({
        type: 'array',
        'x-waddle-widget': 'content-category-multi',
      }),
    ).toBe(true);
    expect(
      schemaPropertyUsesThemeAccent({
        'x-waddle-widget': 'theme-accent',
        oneOf: [],
      }),
    ).toBe(true);
    expect(
      schemaPropertyUsesEnumLabels({
        type: 'string',
        enum: ['a'],
        'x-waddle-enum-labels': { a: 'A' },
      }),
    ).toBe(true);
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
        categoryId: {
          type: 'string',
          'x-waddle-widget': 'content-category',
        },
        qrMode: {
          type: 'string',
          enum: ['hidden', 'left'],
          'x-waddle-enum-labels': { hidden: 'Hidden', left: 'Left' },
        },
        interval_sec: {
          type: 'integer',
          minimum: 5,
          maximum: 3600,
          'x-waddle-widget': 'duration',
        },
      },
    });
    expect(ui.shadow).toEqual({ 'ui:widget': 'WaddleSwitchWidget' });
    expect(ui.density).toEqual({ 'ui:widget': 'WaddleSliderWidget' });
    expect(ui.image_blob_keys).toEqual({ 'ui:field': 'OverlayBlobKeysField' });
    expect(ui.categoryId).toEqual({ 'ui:field': 'ContentCategorySelectField' });
    expect(ui.interval_sec).toEqual({ 'ui:widget': 'WaddleDurationWidget' });
    expect(ui.qrMode).toEqual({ 'ui:widget': 'WaddleEnumSelectWidget' });
  });

  it('normalizeSchemaFieldLabels fills missing property titles', () => {
    const schema = normalizeSchemaFieldLabels({
      type: 'object',
      properties: {
        image_blob_keys: { type: 'array', items: { type: 'string' } },
      },
    });
    const prop = (schema.properties as Record<string, { title?: string }>).image_blob_keys;
    expect(prop?.title).toBe('Image Blob Keys');
  });
});
