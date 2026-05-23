import type {
  CategoryInterestRow,
  RssFeedRow,
  StockSymbolRow,
  WeatherLocationRow,
} from '@/api/interests';
import { formatCategorySeason } from '@/util/categorySeason';
import {
  buildColumnSortOptions,
  columnSortToolbarOptions,
  compareBool,
  compareLocale,
  compareNumber,
  tieBreakLocale,
  type ColumnSortField,
} from '@/util/dataViewColumnSort';

export type InterestTabId = 'locations' | 'rss' | 'stocks' | 'jokes' | 'trivia';

export const INTEREST_DEFAULT_SORT_ID: Record<InterestTabId, string> = {
  locations: 'name',
  rss: 'feed_name',
  stocks: 'symbol',
  jokes: 'label',
  trivia: 'label',
};

const LOCATION_SORT_FIELDS: ColumnSortField<WeatherLocationRow>[] = [
  {
    id: 'name',
    label: 'Name',
    compare: (a, b) => tieBreakLocale(compareLocale(a.name, b.name), a.id, b.id),
  },
  {
    id: 'lat',
    label: 'Lat',
    compare: (a, b) => tieBreakLocale(compareNumber(a.latitude, b.latitude), a.id, b.id),
  },
  {
    id: 'lon',
    label: 'Lon',
    compare: (a, b) => tieBreakLocale(compareNumber(a.longitude, b.longitude), a.id, b.id),
  },
];

function rssFeedName(row: RssFeedRow): string {
  return (row.title?.trim() || row.url).toLowerCase();
}

const RSS_SORT_FIELDS: ColumnSortField<RssFeedRow>[] = [
  {
    id: 'feed_name',
    label: 'Feed name',
    compare: (a, b) =>
      tieBreakLocale(compareLocale(rssFeedName(a), rssFeedName(b)), a.id, b.id),
  },
  {
    id: 'url',
    label: 'URL',
    compare: (a, b) => tieBreakLocale(compareLocale(a.url, b.url), a.id, b.id),
  },
  {
    id: 'poll',
    label: 'Poll interval',
    compare: (a, b) => tieBreakLocale(compareNumber(a.poll_seconds, b.poll_seconds), a.id, b.id),
  },
  {
    id: 'max',
    label: 'Max',
    compare: (a, b) => tieBreakLocale(compareNumber(a.max_articles, b.max_articles), a.id, b.id),
  },
  {
    id: 'interested',
    label: 'Interested',
    compare: (a, b) => tieBreakLocale(compareBool(a.enabled, b.enabled), a.id, b.id),
  },
];

const STOCK_SORT_FIELDS: ColumnSortField<StockSymbolRow>[] = [
  {
    id: 'symbol',
    label: 'Symbol',
    compare: (a, b) => tieBreakLocale(compareLocale(a.symbol, b.symbol), a.id, b.id),
  },
  {
    id: 'display_name',
    label: 'Display name',
    compare: (a, b) =>
      tieBreakLocale(compareLocale(a.display_name, b.display_name), a.id, b.id),
  },
  {
    id: 'category',
    label: 'Category',
    compare: (a, b) => tieBreakLocale(compareLocale(a.category, b.category), a.id, b.id),
  },
  {
    id: 'interested',
    label: 'Interested',
    compare: (a, b) => tieBreakLocale(compareBool(a.enabled, b.enabled), a.id, b.id),
  },
];

function categoryMin(row: CategoryInterestRow): number {
  return row.min_jokes ?? row.min_questions ?? 0;
}

function categoryMax(row: CategoryInterestRow): number {
  return row.max_jokes ?? row.max_questions ?? 0;
}

const CATEGORY_INTEREST_SORT_FIELDS: ColumnSortField<CategoryInterestRow>[] = [
  {
    id: 'label',
    label: 'Label',
    compare: (a, b) => tieBreakLocale(compareLocale(a.label, b.label), a.id, b.id),
  },
  {
    id: 'seasonal',
    label: 'Seasonal',
    compare: (a, b) => tieBreakLocale(compareBool(a.is_seasonal, b.is_seasonal), a.id, b.id),
  },
  {
    id: 'season',
    label: 'Season',
    compare: (a, b) =>
      tieBreakLocale(
        compareLocale(formatCategorySeason(a), formatCategorySeason(b)),
        a.id,
        b.id,
      ),
  },
  {
    id: 'min',
    label: 'Min',
    compare: (a, b) => tieBreakLocale(compareNumber(categoryMin(a), categoryMin(b)), a.id, b.id),
  },
  {
    id: 'max',
    label: 'Max',
    compare: (a, b) => tieBreakLocale(compareNumber(categoryMax(a), categoryMax(b)), a.id, b.id),
  },
];

export function interestSortOptionsForTab(tab: InterestTabId) {
  switch (tab) {
    case 'locations':
      return buildColumnSortOptions(LOCATION_SORT_FIELDS);
    case 'rss':
      return buildColumnSortOptions(RSS_SORT_FIELDS);
    case 'stocks':
      return buildColumnSortOptions(STOCK_SORT_FIELDS);
    case 'jokes':
    case 'trivia':
      return buildColumnSortOptions(CATEGORY_INTEREST_SORT_FIELDS);
  }
}

export function interestSortToolbarForTab(tab: InterestTabId) {
  switch (tab) {
    case 'locations':
      return columnSortToolbarOptions(LOCATION_SORT_FIELDS);
    case 'rss':
      return columnSortToolbarOptions(RSS_SORT_FIELDS);
    case 'stocks':
      return columnSortToolbarOptions(STOCK_SORT_FIELDS);
    case 'jokes':
    case 'trivia':
      return columnSortToolbarOptions(CATEGORY_INTEREST_SORT_FIELDS);
  }
}
