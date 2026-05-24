import { describe, expect, it } from 'vitest';
import { partitionJsonSchemaProperties } from '@/util/schemaTabPartition';

const schema = {
  type: 'object',
  required: ['categoryName', 'scrollDelayMs'],
  properties: {
    categoryName: { type: 'string' },
    scrollDelayMs: { type: 'integer', 'x-waddle-advanced': true },
    hidePastEvents: { type: 'boolean' },
  },
};

describe('partitionJsonSchemaProperties', () => {
  it('keeps non-advanced on basic tab', () => {
    const basic = partitionJsonSchemaProperties(schema, 'basic') as {
      properties: Record<string, unknown>;
      required?: string[];
    };
    expect(Object.keys(basic.properties)).toEqual(['categoryName', 'hidePastEvents']);
    expect(basic.required).toEqual(['categoryName']);
  });

  it('keeps advanced on advanced tab', () => {
    const advanced = partitionJsonSchemaProperties(schema, 'advanced') as {
      properties: Record<string, unknown>;
      required?: string[];
    };
    expect(Object.keys(advanced.properties)).toEqual(['scrollDelayMs']);
    expect(advanced.required).toEqual(['scrollDelayMs']);
  });
});
