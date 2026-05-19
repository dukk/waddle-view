import type { TickerTypeSchemaMeta } from '@/storage/configSchemaCache';

/** Human-facing label for a ticker tape type (registry label when available). */
export function tickerTypeLabel(
  tickerType: string | null | undefined,
  meta?: TickerTypeSchemaMeta | null,
): string {
  const normalized = (tickerType ?? '').trim();
  if (!normalized) return 'unknown';
  const fromLabel = meta?.label?.trim();
  if (fromLabel) return fromLabel;
  return normalized.replace(/_/g, ' ');
}

export function tickerTypeMetaFor(
  tickerTypes: TickerTypeSchemaMeta[],
  tickerType: string,
): TickerTypeSchemaMeta | undefined {
  return tickerTypes.find((m) => m.ticker_type === tickerType);
}
