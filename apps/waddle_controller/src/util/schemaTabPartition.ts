type JsonSchemaObject = Record<string, unknown>;

function asObject(v: unknown): JsonSchemaObject | null {
  return v !== null && typeof v === 'object' && !Array.isArray(v) ? (v as JsonSchemaObject) : null;
}

function isAdvancedProperty(prop: JsonSchemaObject): boolean {
  return prop['x-waddle-advanced'] === true;
}

/** Splits a JSON Schema object properties into basic vs advanced subsets. */
export function partitionJsonSchemaProperties(
  schema: unknown,
  tab: 'basic' | 'advanced',
): unknown {
  const root = asObject(schema);
  if (!root) return schema;

  const properties = asObject(root.properties);
  if (!properties) return schema;

  const filtered: Record<string, unknown> = {};
  for (const [key, rawProp] of Object.entries(properties)) {
    const prop = asObject(rawProp);
    if (!prop) continue;
    const advanced = isAdvancedProperty(prop);
    if (tab === 'advanced' ? advanced : !advanced) {
      filtered[key] = rawProp;
    }
  }

  const required = Array.isArray(root.required)
    ? (root.required as string[]).filter((k) => k in filtered)
    : undefined;

  const next: JsonSchemaObject = { ...root, properties: filtered };
  if (required != null && required.length > 0) {
    next.required = required;
  } else {
    delete next.required;
  }
  return next;
}
