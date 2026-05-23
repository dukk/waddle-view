import type { RJSFSchema } from '@rjsf/utils';
import { integrationConfigBaseUrl } from '@/util/integrationConfig';
import { parseJsonObject } from '@/util/json';
import { prepareRjsfSchema } from '@/util/rjsfSchema';
import { normalizeSchemaFieldLabels } from '@/util/schemaFieldLabel';

const HIDDEN_INTEGRATION_CONFIG_KEYS = new Set(['baseUrl', 'base_url']);

const WEATHER_OPENWEATHERMAP_TYPE = 'weather_openweathermap';

const WEATHER_OPENWEATHERMAP_STRIP_KEYS = new Set([
  'baseUrl',
  'base_url',
  'defaultLocation',
]);

type SchemaNode = Record<string, unknown>;

function asSchemaObject(value: unknown): SchemaNode | null {
  return value !== null && typeof value === 'object' && !Array.isArray(value)
    ? (value as SchemaNode)
    : null;
}

function omitHiddenProperties(node: SchemaNode, hidden: Set<string>): void {
  const properties = asSchemaObject(node.properties);
  if (properties) {
    for (const key of hidden) {
      delete properties[key];
    }
  }
  if (Array.isArray(node.required)) {
    node.required = node.required.filter((key) => !hidden.has(String(key)));
  }
  if (properties) {
    for (const rawProp of Object.values(properties)) {
      const prop = asSchemaObject(rawProp);
      if (!prop) continue;
      omitHiddenProperties(prop, hidden);
      const items = asSchemaObject(prop.items);
      if (items) {
        omitHiddenProperties(items, hidden);
      }
    }
  }
}

/** JSON Schema for integration config forms: hides service URLs and humanizes field labels. */
export function prepareIntegrationOperatorSchema(
  raw: unknown,
  integrationType?: string,
): RJSFSchema {
  const prepared = prepareRjsfSchema(raw);
  const node = structuredClone(prepared) as SchemaNode;
  const hidden = new Set(HIDDEN_INTEGRATION_CONFIG_KEYS);
  if (integrationType === WEATHER_OPENWEATHERMAP_TYPE) {
    hidden.add('defaultLocation');
    node.additionalProperties = false;
  }
  omitHiddenProperties(node, hidden);
  normalizeSchemaFieldLabels(node);
  delete node.title;
  delete node.description;
  return node as RJSFSchema;
}

/** Form state for integration dialogs: drops keys hidden from the operator UI. */
export function operatorIntegrationFormData(
  integrationType: string,
  configJson: unknown,
): Record<string, unknown> {
  return stripIntegrationConfigKeysForSave(integrationType, parseJsonObject(configJson));
}

/** Keeps integration-only fields (e.g. `baseUrl`) when saving operator-edited config. */
export function preserveIntegrationConfigForSave(
  formData: Record<string, unknown>,
  originalConfigJson: unknown,
  integrationType?: string,
): Record<string, unknown> {
  if (integrationType === WEATHER_OPENWEATHERMAP_TYPE) {
    return formData;
  }
  const baseUrl = integrationConfigBaseUrl(originalConfigJson);
  if (baseUrl == null) {
    return formData;
  }
  return { ...formData, baseUrl };
}

/** Removes integration-specific keys that must not persist after operator save. */
export function stripIntegrationConfigKeysForSave(
  integrationType: string,
  config: Record<string, unknown>,
): Record<string, unknown> {
  if (integrationType !== WEATHER_OPENWEATHERMAP_TYPE) {
    return config;
  }
  const out = { ...config };
  for (const key of WEATHER_OPENWEATHERMAP_STRIP_KEYS) {
    delete out[key];
  }
  return out;
}

/** Merges operator form edits with fields hidden from the form. */
export function mergeIntegrationConfigForSave(
  formData: Record<string, unknown>,
  originalConfigJson: unknown,
  integrationType?: string,
): Record<string, unknown> {
  if (integrationType === WEATHER_OPENWEATHERMAP_TYPE) {
    return stripIntegrationConfigKeysForSave(integrationType, { ...formData });
  }
  const original = parseJsonObject(originalConfigJson);
  const merged = {
    ...original,
    ...preserveIntegrationConfigForSave(formData, originalConfigJson, integrationType),
  };
  if (integrationType == null) {
    return merged;
  }
  return stripIntegrationConfigKeysForSave(integrationType, merged);
}
