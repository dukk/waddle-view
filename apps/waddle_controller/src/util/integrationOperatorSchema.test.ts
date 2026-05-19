import { describe, expect, it } from 'vitest';
import validator from '@rjsf/validator-ajv8';
import {
  mergeIntegrationConfigForSave,
  prepareIntegrationOperatorSchema,
} from './integrationOperatorSchema';
import { prepareRjsfSchema } from './rjsfSchema';

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
});
