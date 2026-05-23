import type { SortOption } from '@/util/clientListPipeline';
import { integrationDisplayName } from '@/util/integrationDisplayName';
import {
  buildColumnSortOptions,
  columnSortToolbarOptions,
  compareBool,
  compareLocale,
  compareNumber,
  type ColumnSortField,
} from '@/util/dataViewColumnSort';

export type DataCatalogKind =
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
  | 'dashboard_alerts'
  | 'tasks';

export function rowSortMs(row: Record<string, unknown>): number {
  for (const key of [
    'created_at_ms',
    'published_at',
    'fetched_at_ms',
    'observed_at_ms',
    'start_ms',
    'effective_at',
  ]) {
    const v = row[key];
    if (typeof v === 'number' && Number.isFinite(v)) return v;
  }
  return 0;
}

function str(row: Record<string, unknown>, key: string): string {
  const v = row[key];
  return v == null ? '' : String(v);
}

function num(row: Record<string, unknown>, key: string): number {
  const v = row[key];
  return typeof v === 'number' && Number.isFinite(v) ? v : Number(v) || 0;
}

function integrationSortKey(row: Record<string, unknown>): string {
  const raw = row.integration_type;
  if (raw == null || typeof raw !== 'string' || !raw.trim()) return '';
  return integrationDisplayName(raw.trim());
}

function categorySortKey(
  row: Record<string, unknown>,
  categories: { id: string; label: string }[],
): string {
  const id = String(row.category_id ?? '');
  if (!id) return '';
  return categories.find((c) => c.id === id)?.label ?? id;
}

function quoteCategoriesSortKey(row: Record<string, unknown>): string {
  const ids = row.category_ids;
  if (!Array.isArray(ids)) return '';
  return ids.map(String).join(', ');
}

function calendarCategorySortKey(
  row: Record<string, unknown>,
  categories: { id: string; label: string }[],
): string {
  const ids = Array.isArray(row.category_ids) ? (row.category_ids as string[]) : [];
  const primary = String(row.category_id ?? '');
  const allIds = ids.length > 0 ? ids : primary ? [primary] : [];
  return allIds.map((id) => categories.find((c) => c.id === id)?.label ?? id).join(', ');
}

function fieldsForKind(
  kind: DataCatalogKind,
  categories: { id: string; label: string }[],
): ColumnSortField<Record<string, unknown>>[] {
  const observed: ColumnSortField<Record<string, unknown>> = {
    id: 'observed',
    label: 'Observed',
    compare: (a, b) => compareNumber(rowSortMs(a), rowSortMs(b)),
  };
  const source: ColumnSortField<Record<string, unknown>> = {
    id: 'source',
    label: 'Source',
    compare: (a, b) => compareLocale(integrationSortKey(a), integrationSortKey(b)),
  };

  switch (kind) {
    case 'jokes':
      return [
        {
          id: 'category',
          label: 'Category',
          compare: (a, b) =>
            compareLocale(categorySortKey(a, categories), categorySortKey(b, categories)),
        },
        { id: 'setup', label: 'Setup', compare: (a, b) => compareLocale(str(a, 'setup'), str(b, 'setup')) },
        {
          id: 'punchline',
          label: 'Punchline',
          compare: (a, b) => compareLocale(str(a, 'punchline'), str(b, 'punchline')),
        },
        source,
        observed,
      ];
    case 'trivia':
      return [
        {
          id: 'category',
          label: 'Category',
          compare: (a, b) =>
            compareLocale(categorySortKey(a, categories), categorySortKey(b, categories)),
        },
        {
          id: 'question',
          label: 'Question',
          compare: (a, b) => compareLocale(str(a, 'question'), str(b, 'question')),
        },
        source,
        observed,
      ];
    case 'news':
      return [
        { id: 'title', label: 'Title', compare: (a, b) => compareLocale(str(a, 'title'), str(b, 'title')) },
        {
          id: 'summary',
          label: 'Summary',
          compare: (a, b) => compareLocale(str(a, 'summary'), str(b, 'summary')),
        },
        source,
        observed,
      ];
    case 'photos':
      return [
        {
          id: 'alt',
          label: 'Alt / photographer',
          compare: (a, b) =>
            compareLocale(
              `${str(a, 'alt_text')} ${str(a, 'photographer')}`,
              `${str(b, 'alt_text')} ${str(b, 'photographer')}`,
            ),
        },
        source,
        observed,
      ];
    case 'quoterism_quotes':
      return [
        { id: 'author', label: 'Author', compare: (a, b) => compareLocale(str(a, 'author'), str(b, 'author')) },
        { id: 'quote', label: 'Quote', compare: (a, b) => compareLocale(str(a, 'text'), str(b, 'text')) },
        {
          id: 'categories',
          label: 'Categories',
          compare: (a, b) =>
            compareLocale(quoteCategoriesSortKey(a), quoteCategoriesSortKey(b)),
        },
        source,
        observed,
      ];
    case 'videos':
      return [
        {
          id: 'alt',
          label: 'Alt / photographer',
          compare: (a, b) =>
            compareLocale(
              `${str(a, 'alt_text')} ${str(a, 'photographer')}`,
              `${str(b, 'alt_text')} ${str(b, 'photographer')}`,
            ),
        },
        {
          id: 'duration',
          label: 'Duration',
          compare: (a, b) => compareNumber(num(a, 'duration_ms'), num(b, 'duration_ms')),
        },
        source,
        observed,
      ];
    case 'stocks':
      return [
        { id: 'symbol', label: 'Symbol', compare: (a, b) => compareLocale(str(a, 'symbol'), str(b, 'symbol')) },
        { id: 'name', label: 'Name', compare: (a, b) => compareLocale(str(a, 'name'), str(b, 'name')) },
        { id: 'price', label: 'Price', compare: (a, b) => compareNumber(num(a, 'price'), num(b, 'price')) },
        {
          id: 'change',
          label: 'Change %',
          compare: (a, b) => compareNumber(num(a, 'change_percent'), num(b, 'change_percent')),
        },
        observed,
        source,
      ];
    case 'weather':
      return [
        {
          id: 'location',
          label: 'Location',
          compare: (a, b) => compareLocale(str(a, 'location_name'), str(b, 'location_name')),
        },
        {
          id: 'temp',
          label: 'Temp / description',
          compare: (a, b) =>
            compareLocale(
              `${num(a, 'temperature_f')} ${str(a, 'description')}`,
              `${num(b, 'temperature_f')} ${str(b, 'description')}`,
            ),
        },
        observed,
        source,
      ];
    case 'weather_alerts':
      return [
        {
          id: 'location',
          label: 'Location',
          compare: (a, b) => compareLocale(str(a, 'location_name'), str(b, 'location_name')),
        },
        { id: 'event', label: 'Event', compare: (a, b) => compareLocale(str(a, 'event'), str(b, 'event')) },
        {
          id: 'headline',
          label: 'Headline',
          compare: (a, b) => compareLocale(str(a, 'headline'), str(b, 'headline')),
        },
        {
          id: 'severity',
          label: 'Severity',
          compare: (a, b) => compareLocale(str(a, 'severity'), str(b, 'severity')),
        },
        source,
        observed,
      ];
    case 'dashboard_alerts':
      return [
        {
          id: 'status',
          label: 'Status',
          compare: (a, b) => compareLocale(str(a, 'status'), str(b, 'status')),
        },
        { id: 'title', label: 'Title', compare: (a, b) => compareLocale(str(a, 'title'), str(b, 'title')) },
        { id: 'body', label: 'Body', compare: (a, b) => compareLocale(str(a, 'body'), str(b, 'body')) },
        {
          id: 'severity',
          label: 'Severity',
          compare: (a, b) => compareLocale(str(a, 'severity'), str(b, 'severity')),
        },
        {
          id: 'priority',
          label: 'Priority',
          compare: (a, b) => compareNumber(num(a, 'priority'), num(b, 'priority')),
        },
        source,
        {
          id: 'created',
          label: 'Created',
          compare: (a, b) => compareNumber(rowSortMs(a), rowSortMs(b)),
        },
      ];
    case 'calendar_events':
      return [
        { id: 'title', label: 'Title', compare: (a, b) => compareLocale(str(a, 'title'), str(b, 'title')) },
        {
          id: 'start',
          label: 'Start',
          compare: (a, b) => compareNumber(num(a, 'start_ms'), num(b, 'start_ms')),
        },
        {
          id: 'end',
          label: 'End',
          compare: (a, b) => compareNumber(num(a, 'end_ms'), num(b, 'end_ms')),
        },
        {
          id: 'all_day',
          label: 'All-day',
          compare: (a, b) => compareBool(Boolean(a.all_day), Boolean(b.all_day)),
        },
        {
          id: 'location',
          label: 'Location',
          compare: (a, b) => compareLocale(str(a, 'location'), str(b, 'location')),
        },
        {
          id: 'category',
          label: 'Category',
          compare: (a, b) =>
            compareLocale(
              calendarCategorySortKey(a, categories),
              calendarCategorySortKey(b, categories),
            ),
        },
        {
          id: 'integration',
          label: 'Integration',
          compare: (a, b) => compareLocale(integrationSortKey(a), integrationSortKey(b)),
        },
        {
          id: 'account',
          label: 'Account / feed',
          compare: (a, b) =>
            compareLocale(
              `${str(a, 'account_label')} ${str(a, 'feed_label')}`,
              `${str(b, 'account_label')} ${str(b, 'feed_label')}`,
            ),
        },
      ];
    case 'tasks':
      return [
        { id: 'title', label: 'Title', compare: (a, b) => compareLocale(str(a, 'title'), str(b, 'title')) },
        { id: 'list', label: 'List', compare: (a, b) => compareLocale(str(a, 'list_name'), str(b, 'list_name')) },
        { id: 'board', label: 'Board', compare: (a, b) => compareLocale(str(a, 'board_key'), str(b, 'board_key')) },
        {
          id: 'due',
          label: 'Due',
          compare: (a, b) => compareNumber(num(a, 'due_ms'), num(b, 'due_ms')),
        },
        {
          id: 'done',
          label: 'Done',
          compare: (a, b) => compareBool(Boolean(a.completed), Boolean(b.completed)),
        },
        {
          id: 'integration',
          label: 'Integration',
          compare: (a, b) => compareLocale(integrationSortKey(a), integrationSortKey(b)),
        },
      ];
  }
}

const DEFAULT_DATA_SORT_ID: Record<DataCatalogKind, string> = {
  calendar_events: 'start',
  jokes: 'setup',
  trivia: 'question',
  news: 'title',
  photos: 'alt',
  quoterism_quotes: 'quote',
  videos: 'duration',
  stocks: 'symbol',
  weather: 'location',
  weather_alerts: 'event',
  dashboard_alerts: 'created',
  tasks: 'title',
};

export function defaultDataSortIdForKind(kind: DataCatalogKind): string {
  return DEFAULT_DATA_SORT_ID[kind];
}

export function dataSortOptionsForKind(
  kind: DataCatalogKind,
  categories: { id: string; label: string }[],
): SortOption<Record<string, unknown>>[] {
  return buildColumnSortOptions(fieldsForKind(kind, categories));
}

export function dataSortToolbarForKind(
  kind: DataCatalogKind,
  categories: { id: string; label: string }[],
): { id: string; label: string }[] {
  return columnSortToolbarOptions(fieldsForKind(kind, categories));
}
