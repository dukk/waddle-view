import type { IntegrationRow } from '@/api/integrations';

/** Data browser tab ids that integrations can deep-link into. */
export type CatalogDataKind =
  | 'calendar_events'
  | 'jokes'
  | 'trivia'
  | 'news'
  | 'photos'
  | 'quoterism_quotes'
  | 'videos'
  | 'stocks'
  | 'weather'
  | 'weather_alerts'
  | 'tasks';

export type DataCatalogIntegrationFilter = {
  integrationType: string;
  integrationId: string;
};

const CATALOG_DATA_KINDS: readonly CatalogDataKind[] = [
  'calendar_events',
  'jokes',
  'trivia',
  'news',
  'photos',
  'quoterism_quotes',
  'videos',
  'stocks',
  'weather',
  'weather_alerts',
  'tasks',
];

function isCatalogDataKind(value: string): value is CatalogDataKind {
  return (CATALOG_DATA_KINDS as readonly string[]).includes(value);
}

/** Maps an integration `integration_type` to the Data browser tab, or null when no catalog applies. */
export function catalogDataKindForIntegrationType(integrationType: string): CatalogDataKind | null {
  const type = integrationType.trim();
  if (!type) return null;
  if (type.startsWith('weather_alerts_')) return 'weather_alerts';
  if (type.startsWith('weather_')) return 'weather';
  if (type.startsWith('calendar_')) return 'calendar_events';
  if (type.startsWith('joke_')) return 'jokes';
  if (type.startsWith('trivia_')) return 'trivia';
  if (type.startsWith('news_')) return 'news';
  if (type.startsWith('photo_')) return 'photos';
  if (type.startsWith('video_')) return 'videos';
  if (type.startsWith('quote_')) return 'quoterism_quotes';
  if (type.startsWith('stock_')) return 'stocks';
  if (type.startsWith('tasks_')) return 'tasks';
  return null;
}

/** Catalog `source` query needle for calendar event filtering. */
export function calendarCatalogSourceNeedle(integrationType: string): string | null {
  switch (integrationType.trim()) {
    case 'calendar_google':
      return 'google_calendar';
    case 'calendar_outlook':
      return 'outlook_calendar';
    case 'calendar_ical':
      return 'ical_feed';
    case 'calendar_mealviewer':
      return 'mealviewer';
    default:
      return null;
  }
}

export function dataCatalogPath(integration: Pick<IntegrationRow, 'id' | 'integration_type'>): string | null {
  const kind = catalogDataKindForIntegrationType(integration.integration_type);
  if (!kind) return null;
  const p = new URLSearchParams();
  p.set('kind', kind);
  p.set('integration_type', integration.integration_type);
  p.set('integration_id', integration.id);
  return `/data?${p.toString()}`;
}

/** Extra catalog API query params when filtering by integration on the Data page. */
export function catalogFilterParamsForIntegration(
  kind: CatalogDataKind,
  integration: Pick<IntegrationRow, 'id' | 'integration_type'>,
): URLSearchParams {
  const p = new URLSearchParams();
  switch (kind) {
    case 'photos':
    case 'videos':
      p.set('data_provider', integration.integration_type);
      break;
    case 'calendar_events': {
      const source = calendarCatalogSourceNeedle(integration.integration_type);
      if (source) p.set('source', source);
      break;
    }
    case 'trivia':
      // Display catalog API uses `integration_type` to filter the integrationId column.
      p.set('integration_type', integration.id);
      break;
    case 'tasks':
      p.set('integration_id', integration.id);
      break;
    default:
      break;
  }
  return p;
}

export function parseDataCatalogSearchParams(params: URLSearchParams): {
  kind: CatalogDataKind | null;
  integrationType: string | null;
  integrationId: string | null;
} {
  const kindRaw = params.get('kind')?.trim() ?? '';
  const integrationType = params.get('integration_type')?.trim() || null;
  const integrationId = params.get('integration_id')?.trim() || null;
  return {
    kind: isCatalogDataKind(kindRaw) ? kindRaw : null,
    integrationType,
    integrationId,
  };
}

export function buildDataCatalogSearchParams(input: {
  kind: string;
  integrationFilter: DataCatalogIntegrationFilter | null;
}): URLSearchParams {
  const p = new URLSearchParams();
  p.set('kind', input.kind);
  if (input.integrationFilter) {
    p.set('integration_type', input.integrationFilter.integrationType);
    p.set('integration_id', input.integrationFilter.integrationId);
  }
  return p;
}

export function integrationFilterFromSearchParams(
  params: URLSearchParams,
): DataCatalogIntegrationFilter | null {
  const { integrationType, integrationId } = parseDataCatalogSearchParams(params);
  if (!integrationType || !integrationId) return null;
  return { integrationType, integrationId };
}
