import { describe, expect, it } from 'vitest';
import { sortByOption } from '@/util/clientListPipeline';
import {
  dataSortOptionsForKind,
  dataSortToolbarForKind,
  defaultDataSortIdForKind,
  rowSortMs,
} from './dataCatalogSort';

const categories = [
  { id: 'cat-a', label: 'Alpha' },
  { id: 'cat-b', label: 'Beta' },
];

function sortRows(
  kind: Parameters<typeof dataSortOptionsForKind>[0],
  sortId: string,
  rows: Record<string, unknown>[],
): Record<string, unknown>[] {
  const options = dataSortOptionsForKind(kind, categories);
  const option = options.find((o) => o.id === sortId) ?? options[0]!;
  return sortByOption(rows, option);
}

describe('rowSortMs', () => {
  it('returns first finite timestamp field in priority order', () => {
    expect(rowSortMs({ created_at_ms: 100 })).toBe(100);
    expect(rowSortMs({ published_at: 200, created_at_ms: 100 })).toBe(100);
    expect(rowSortMs({ fetched_at_ms: 300, published_at: 200 })).toBe(200);
    expect(rowSortMs({ observed_at_ms: 400, fetched_at_ms: 300 })).toBe(300);
    expect(rowSortMs({ start_ms: 500, observed_at_ms: 400 })).toBe(400);
    expect(rowSortMs({ effective_at: 600, start_ms: 500 })).toBe(500);
  });

  it('returns 0 when no valid timestamp', () => {
    expect(rowSortMs({})).toBe(0);
    expect(rowSortMs({ created_at_ms: NaN })).toBe(0);
    expect(rowSortMs({ created_at_ms: 'not-a-number' })).toBe(0);
  });
});

describe('defaultDataSortIdForKind', () => {
  it('returns expected default column ids', () => {
    expect(defaultDataSortIdForKind('jokes')).toBe('setup');
    expect(defaultDataSortIdForKind('calendar_events')).toBe('start');
    expect(defaultDataSortIdForKind('dashboard_alerts')).toBe('created');
    expect(defaultDataSortIdForKind('stocks')).toBe('symbol');
    expect(defaultDataSortIdForKind('quoterism_quotes')).toBe('quote');
  });
});

describe('dataSortOptionsForKind', () => {
  it('jokes sorts by category label and setup', () => {
    const rows = [
      { category_id: 'cat-b', setup: 'B setup' },
      { category_id: 'cat-a', setup: 'A setup' },
    ];
    const byCategory = sortRows('jokes', 'category', rows);
    expect(byCategory[0]!.setup).toBe('A setup');
    const bySetup = sortRows('jokes', 'setup', [
      { setup: 'zebra' },
      { setup: 'alpha' },
    ]);
    expect(bySetup[0]!.setup).toBe('alpha');
  });

  it('calendar_events sorts by start and resolves category_ids', () => {
    const rows = [
      { start_ms: 2000, category_ids: ['cat-b'] },
      { start_ms: 1000, category_id: 'cat-a' },
    ];
    const byStart = sortRows('calendar_events', 'start', rows);
    expect(byStart[0]!.start_ms).toBe(1000);
    const byCategory = sortRows('calendar_events', 'category', [
      { category_ids: ['cat-b', 'cat-a'] },
      { category_id: 'cat-a' },
    ]);
    expect(byCategory[0]!.category_id).toBe('cat-a');
  });

  it('stocks sorts by symbol and price', () => {
    const bySymbol = sortRows('stocks', 'symbol', [
      { symbol: 'ZZZ' },
      { symbol: 'AAA' },
    ]);
    expect(bySymbol[0]!.symbol).toBe('AAA');
    const byPrice = sortRows('stocks', 'price', [
      { price: 50 },
      { price: 10 },
    ]);
    expect(byPrice[0]!.price).toBe(10);
  });

  it('quoterism_quotes sorts by category_ids join key', () => {
    const sorted = sortRows('quoterism_quotes', 'categories', [
      { category_ids: ['z', 'y'] },
      { category_ids: ['a'] },
    ]);
    expect(sorted[0]!.category_ids).toEqual(['a']);
  });

  it('news sorts by title', () => {
    const sorted = sortRows('news', 'title', [
      { title: 'Zebra' },
      { title: 'Alpha' },
    ]);
    expect(sorted[0]!.title).toBe('Alpha');
  });

  it('weather_alerts sorts by event', () => {
    const sorted = sortRows('weather_alerts', 'event', [
      { event: 'Wind' },
      { event: 'Flood' },
    ]);
    expect(sorted[0]!.event).toBe('Flood');
  });

  it('trivia, photos, videos, weather, dashboard_alerts, and tasks expose options', () => {
    for (const kind of [
      'trivia',
      'photos',
      'videos',
      'weather',
      'dashboard_alerts',
      'tasks',
    ] as const) {
      const options = dataSortOptionsForKind(kind, categories);
      expect(options.length).toBeGreaterThan(0);
      expect(options.some((o) => o.id === defaultDataSortIdForKind(kind))).toBe(true);
    }
  });

  it('observed sort uses rowSortMs', () => {
    const sorted = sortRows('news', 'observed', [
      { fetched_at_ms: 300 },
      { published_at: 100 },
    ]);
    expect(rowSortMs(sorted[0]!)).toBe(100);
  });
});

describe('dataSortToolbarForKind', () => {
  it('returns toolbar ids matching sort option ids for jokes', () => {
    const toolbar = dataSortToolbarForKind('jokes', categories);
    const options = dataSortOptionsForKind('jokes', categories);
    expect(toolbar.map((t) => t.id)).toEqual(options.map((o) => o.id));
    expect(toolbar.some((t) => t.label === 'Setup')).toBe(true);
  });
});
