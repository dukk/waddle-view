import { describe, expect, it } from 'vitest';
import validator from '@rjsf/validator-ajv8';
import {
  mergeIntegrationConfigForSave,
  prepareIntegrationOperatorSchema,
} from './integrationOperatorSchema';
import { prepareRjsfSchema } from './rjsfSchema';

const INTEGRATION_TYPES_WITH_BASE_URL = [
  'photo_pexels',
  'weather_openweathermap',
  'home_assistant',
  'calendar_outlook',
  'calendar_google',
  'calendar_ical',
  'news_rss',
] as const;

function schemaHasHiddenUrlKeys(node: unknown): boolean {
  if (node == null || typeof node !== 'object' || Array.isArray(node)) {
    return false;
  }
  const o = node as Record<string, unknown>;
  if ('baseUrl' in o || 'base_url' in o) {
    return true;
  }
  const properties = o.properties;
  if (properties && typeof properties === 'object' && !Array.isArray(properties)) {
    for (const prop of Object.values(properties)) {
      if (schemaHasHiddenUrlKeys(prop)) return true;
    }
  }
  const items = o.items;
  if (items && typeof items === 'object') {
    if (schemaHasHiddenUrlKeys(items)) return true;
  }
  return false;
}

const integrationSchema = {
  $schema: 'https://json-schema.org/draft/2020-12/schema',
  title: 'PexelsPhotoProviderConfig',
  description: 'Photo rate limits.',
  type: 'object',
  properties: {
    baseUrl: { type: 'string' },
    maxPhotos: { type: 'integer', minimum: 1 },
  },
  required: ['maxPhotos'],
  additionalProperties: true,
};

describe('prepareIntegrationOperatorSchema', () => {
  it('omits baseUrl from properties and required', () => {
    const schema = prepareIntegrationOperatorSchema(integrationSchema);
    expect(schema.properties).not.toHaveProperty('baseUrl');
    expect(schema.required).toEqual(['maxPhotos']);
    expect(schema.title).toBeUndefined();
    expect(schema.description).toBeUndefined();
  });

  it('adds human titles for property keys', () => {
    const schema = prepareIntegrationOperatorSchema(integrationSchema);
    const maxPhotos = (schema.properties as Record<string, { title?: string }>).maxPhotos;
    expect(maxPhotos?.title).toBe('Max Photos');
  });

  it('validates saved config when baseUrl is preserved from the original row', () => {
    const fullSchema = prepareRjsfSchema(integrationSchema);
    const saved = mergeIntegrationConfigForSave(
      { maxPhotos: 10 },
      { baseUrl: 'https://api.pexels.com', maxPhotos: 5 },
    );
    const { errors } = validator.validateFormData(saved, fullSchema);
    expect(errors).toEqual([]);
  });

  it('omits nested baseUrl in array item schemas', () => {
    const nested = {
      type: 'object',
      properties: {
        baseUrl: { type: 'string' },
        accounts: {
          type: 'array',
          items: {
            type: 'object',
            properties: {
              base_url: { type: 'string' },
              name: { type: 'string' },
            },
          },
        },
      },
    };
    const schema = prepareIntegrationOperatorSchema(nested);
    expect(schemaHasHiddenUrlKeys(schema)).toBe(false);
  });

  it.each(INTEGRATION_TYPES_WITH_BASE_URL)(
    'operator schema for %s has no baseUrl keys',
    (integrationType) => {
      const raw = {
        title: `${integrationType} config`,
        type: 'object',
        properties: {
          baseUrl: { type: 'string', description: 'Service root' },
          base_url: { type: 'string' },
          pollSeconds: { type: 'integer' },
        },
        required: ['baseUrl'],
      };
      const schema = prepareIntegrationOperatorSchema(raw);
      expect(schemaHasHiddenUrlKeys(schema)).toBe(false);
      expect(schema.required ?? []).not.toContain('baseUrl');
    },
  );
});
