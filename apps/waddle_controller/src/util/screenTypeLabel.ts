import type { ScreenTypeSchemaMeta } from '@/storage/configSchemaCache';
import { parseJsonObject } from '@/util/json';

function titleFromSchema(schema: unknown): string | null {
  const o = parseJsonObject(schema);
  const title = o.title;
  if (typeof title === 'string' && title.trim()) {
    return title.trim();
  }
  return null;
}

/** Human-facing label for a screen type (registry label when available). */
export function screenTypeLabel(
  screenType: string | null | undefined,
  meta?: ScreenTypeSchemaMeta | null,
): string {
  const normalized = (screenType ?? '').trim();
  if (!normalized) return 'unknown';
  const fromLabel = meta?.label?.trim();
  if (fromLabel) return fromLabel;
  const fromSchema = titleFromSchema(meta?.config_json_schema);
  if (fromSchema) return fromSchema;
  return normalized.replace(/_/g, ' ');
}

/** Lookup meta for a screen type from the cached bundle list. */
export function screenTypeMetaFor(
  screenTypes: ScreenTypeSchemaMeta[],
  screenType: string,
): ScreenTypeSchemaMeta | undefined {
  return screenTypes.find((m) => m.screen_type === screenType);
}
