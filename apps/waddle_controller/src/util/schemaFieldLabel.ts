/** Token segments inside schema property keys (camelCase or snake_case). */
const WORD_DISPLAY: Record<string, string> = {
  api: 'API',
  url: 'URL',
  uri: 'URI',
  id: 'ID',
  ids: 'IDs',
  rss: 'RSS',
  nws: 'NWS',
  ical: 'iCal',
  ics: 'ICS',
  oauth: 'OAuth',
  json: 'JSON',
  html: 'HTML',
  http: 'HTTP',
  https: 'HTTPS',
  pi: 'Pi',
  ai: 'AI',
  openai: 'OpenAI',
  onedrive: 'OneDrive',
  opentdb: 'OpenTDB',
  finnhub: 'Finnhub',
};

function capitalizeToken(word: string): string {
  if (word.length === 0) return word;
  const lower = word.toLowerCase();
  if (WORD_DISPLAY[lower]) return WORD_DISPLAY[lower]!;
  return word.charAt(0).toUpperCase() + word.slice(1).toLowerCase();
}

/** Splits `camelCase`, `snake_case`, and `kebab-case` keys into words. */
export function splitSchemaPropertyKey(key: string): string[] {
  return key
    .replace(/([a-z0-9])([A-Z])/g, '$1 $2')
    .replace(/[_-]+/g, ' ')
    .split(/\s+/)
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
}

/** Human label for a JSON Schema property key shown in operator config forms. */
export function schemaPropertyLabel(key: string): string {
  const parts = splitSchemaPropertyKey(key);
  if (parts.length === 0) return key;
  return parts.map(capitalizeToken).join(' ');
}

type SchemaNode = Record<string, unknown>;

function asSchemaObject(value: unknown): SchemaNode | null {
  return value !== null && typeof value === 'object' && !Array.isArray(value)
    ? (value as SchemaNode)
    : null;
}

function applySchemaPropertyTitles(node: SchemaNode): void {
  const properties = asSchemaObject(node.properties);
  if (!properties) return;

  for (const [key, rawProp] of Object.entries(properties)) {
    const prop = asSchemaObject(rawProp);
    if (!prop) continue;
    const title = prop.title;
    if (typeof title !== 'string' || title.trim().length === 0) {
      prop.title = schemaPropertyLabel(key);
    }
    applySchemaPropertyTitles(prop);
    const items = asSchemaObject(prop.items);
    if (items) {
      applySchemaPropertyTitles(items);
    }
  }
}

/** Fills missing JSON Schema `title` values from property keys (does not clone). */
export function normalizeSchemaFieldLabels<T extends Record<string, unknown>>(schema: T): T {
  applySchemaPropertyTitles(schema);
  return schema;
}
