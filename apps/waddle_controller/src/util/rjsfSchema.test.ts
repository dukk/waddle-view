import { describe, expect, it } from 'vitest';
import validator from '@rjsf/validator-ajv8';
import { prepareRjsfSchema, validateConfigAgainstSchema } from './rjsfSchema';

const draft2020WebPageSchema = {
  $schema: 'https://json-schema.org/draft/2020-12/schema',
  type: 'object',
  properties: {
    url: { type: 'string', minLength: 1 },
  },
  required: ['url'],
  additionalProperties: true,
};

describe('prepareRjsfSchema', () => {
  it('removes draft 2020-12 $schema so ajv8 can compile', () => {
    const schema = prepareRjsfSchema(draft2020WebPageSchema);
    expect(schema).not.toHaveProperty('$schema');
    const { errors } = validator.validateFormData(
      { url: 'https://example.com' },
      schema,
    );
    expect(errors).toEqual([]);
  });

  it('does not fail with meta-schema resolution error on invalid data', () => {
    const schema = prepareRjsfSchema(draft2020WebPageSchema);
    const { errors } = validator.validateFormData({}, schema);
    expect(errors.length).toBeGreaterThan(0);
    expect(
      errors.some((e) =>
        (e.message ?? '').includes('no schema with key or ref'),
      ),
    ).toBe(false);
  });

  it('validateConfigAgainstSchema returns field errors not ajv meta errors', () => {
    const messages = validateConfigAgainstSchema({}, draft2020WebPageSchema);
    expect(messages.length).toBeGreaterThan(0);
    expect(messages.some((m) => m.includes('no schema with key or ref'))).toBe(
      false,
    );
  });
});
