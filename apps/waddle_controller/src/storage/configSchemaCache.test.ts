import { describe, expect, it, beforeEach } from 'vitest';
import {
  clearConfigSchemas,
  exampleForScreenType,
  labelForIntegrationType,
  labelForOverlayType,
  labelForScreenType,
  labelForTickerType,
  loadConfigSchemas,
  saveConfigSchemas,
  schemaForScreenType,
  type ConfigSchemasBundle,
} from './configSchemaCache';

const sampleBundle: ConfigSchemasBundle = {
  screen_types: [
    {
      screen_type: 'weather',
      label: 'Weather',
      config_json_schema: { type: 'object', properties: { city: { type: 'string' } } },
      example_config_json: { city: 'Boston' },
    },
  ],
  ticker_tape_types: [
    {
      ticker_type: 'news',
      label: 'News',
      config_json_schema: { type: 'object' },
    },
  ],
  overlay_types: [
    {
      overlay_type: 'shape_rain',
      label: 'Shape rain',
    },
  ],
  integration_types: [
    {
      integration_type: 'stub',
      label: 'Stub collector',
      requires_accounts: false,
      config_json_schema: { type: 'object' },
      example_config_json: {},
    },
  ],
};

describe('configSchemaCache', () => {
  beforeEach(() => {
    localStorage.clear();
  });

  it('round-trips bundle per display id', () => {
    saveConfigSchemas('d1', sampleBundle);
    expect(loadConfigSchemas('d1')).toEqual(sampleBundle);
    expect(loadConfigSchemas('d2')).toBeNull();
  });

  it('clearConfigSchemas removes entry', () => {
    saveConfigSchemas('d1', sampleBundle);
    clearConfigSchemas('d1');
    expect(loadConfigSchemas('d1')).toBeNull();
  });

  it('lookup helpers resolve by type', () => {
    const bundle = loadConfigSchemas('missing');
    expect(schemaForScreenType(bundle, 'weather')).toBeUndefined();
    saveConfigSchemas('d1', sampleBundle);
    const loaded = loadConfigSchemas('d1');
    expect(schemaForScreenType(loaded, 'weather')).toEqual({
      type: 'object',
      properties: { city: { type: 'string' } },
    });
    expect(exampleForScreenType(loaded, 'weather')).toEqual({ city: 'Boston' });
    expect(labelForIntegrationType(loaded, 'stub')).toBe('Stub collector');
    expect(labelForScreenType(loaded, 'weather')).toBe('Weather');
    expect(labelForTickerType(loaded, 'news')).toBe('News');
    expect(labelForOverlayType(loaded, 'shape_rain')).toBe('Shape rain');
  });
});
