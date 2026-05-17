import type { RJSFSchema } from '@rjsf/utils';
import validator from '@rjsf/validator-ajv8';
import { parseJsonObject } from '@/util/json';

const permissiveObjectSchema: RJSFSchema = {
  type: 'object',
  additionalProperties: true,
};

/**
 * JSON Schemas stored on the display use draft 2020-12 in `$schema` for documentation.
 * `@rjsf/validator-ajv8` compiles with AJV8 draft-07 rules and does not ship the
 * 2020-12 meta-schema, which triggers:
 * `no schema with key or ref "https://json-schema.org/draft/2020-12/schema"`.
 *
 * Strip `$schema` before passing schemas to RJSF forms / AJV validation.
 */
export function prepareRjsfSchema(raw: unknown): RJSFSchema {
  const o = parseJsonObject(raw);
  if (Object.keys(o).length === 0) {
    return permissiveObjectSchema;
  }
  if (!('$schema' in o)) {
    return o as RJSFSchema;
  }
  const rest = { ...o };
  delete rest.$schema;
  return rest as RJSFSchema;
}

/** Validate [formData] against a schema from the display API (after [prepareRjsfSchema]). */
export function validateConfigAgainstSchema(
  formData: Record<string, unknown>,
  rawSchema: unknown,
): string[] {
  const schema = prepareRjsfSchema(rawSchema);
  const { errors } = validator.validateFormData(formData, schema);
  return errors.map((e) => e.stack ?? e.message ?? 'Validation error');
}
