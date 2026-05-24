import { describe, expect, it } from 'vitest';
import type { CategoryInterestRow, RssFeedRow, StockSymbolRow, WeatherLocationRow } from '@/api/interests';
import { sortByOption } from '@/util/clientListPipeline';
import {
  INTEREST_DEFAULT_SORT_ID,
  interestSortOptionsForTab,
  interestSortToolbarForTab,
} from './interestTabSort';

const tabs = ['locations', 'rss', 'stocks', 'jokes', 'trivia'] as const;

describe('interestSortOptionsForTab', () => {
  it('returns non-empty options with expected default id per tab', () => {
    for (const tab of tabs) {
      const options = interestSortOptionsForTab(tab);
      expect(options.length).toBeGreaterThan(0);
      expect(options.some((o) => o.id === INTEREST_DEFAULT_SORT_ID[tab])).toBe(true);
    }
  });
});

describe('RSS feed_name sort', () => {
  it('uses title when present, otherwise url', () => {
    const options = interestSortOptionsForTab('rss');
    const feedName = options.find((o) => o.id === 'feed_name')!;
    const rows: RssFeedRow[] = [
      {
        id: 'b',
        url: 'https://b.example/feed',
        title: 'Beta Feed',
        category: 'news',
        poll_seconds: 60,
        max_articles: 10,
        enabled: true,
        last_fetched_at: null,
        consecutive_failures: 0,
        next_retry_at: null,
      },
      {
        id: 'a',
        url: 'https://a.example/feed',
        title: 'Alpha Feed',
        category: 'news',
        poll_seconds: 60,
        max_articles: 10,
        enabled: true,
        last_fetched_at: null,
        consecutive_failures: 0,
        next_retry_at: null,
      },
    ];
    const sorted = sortByOption(rows, feedName);
    expect(sorted[0]!.id).toBe('a');
    const urlOnly: RssFeedRow[] = [
      {
        id: 'z',
        url: 'https://z.example/rss',
        title: null,
        category: 'news',
        poll_seconds: 60,
        max_articles: 10,
        enabled: true,
        last_fetched_at: null,
        consecutive_failures: 0,
        next_retry_at: null,
      },
      {
        id: 'a',
        url: 'https://a.example/rss',
        title: null,
        category: 'news',
        poll_seconds: 60,
        max_articles: 10,
        enabled: true,
        last_fetched_at: null,
        consecutive_failures: 0,
        next_retry_at: null,
      },
    ];
    const byUrl = sortByOption(urlOnly, feedName);
    expect(byUrl[0]!.url).toContain('a.example');
  });
});

describe('sort execution per tab', () => {
  it('locations sorts by name', () => {
    const options = interestSortOptionsForTab('locations');
    const name = options.find((o) => o.id === 'name')!;
    const rows: WeatherLocationRow[] = [
      {
        id: 'b',
        name: 'Zulu',
        latitude: 0,
        longitude: 0,
        category: 'home',
        include_weather: true,
        include_weather_alerts: true,
        include_local_news: false,
      },
      {
        id: 'a',
        name: 'Alpha',
        latitude: 0,
        longitude: 0,
        category: 'home',
        include_weather: true,
        include_weather_alerts: true,
        include_local_news: false,
      },
    ];
    expect(sortByOption(rows, name)[0]!.name).toBe('Alpha');
  });

  it('stocks sorts by symbol', () => {
    const options = interestSortOptionsForTab('stocks');
    const symbol = options.find((o) => o.id === 'symbol')!;
    const rows: StockSymbolRow[] = [
      { id: 'b', symbol: 'ZZZ', display_name: 'Z', category: 'tech', enabled: true },
      { id: 'a', symbol: 'AAA', display_name: 'A', category: 'tech', enabled: true },
    ];
    expect(sortByOption(rows, symbol)[0]!.symbol).toBe('AAA');
  });

  it('jokes sorts by label', () => {
    const options = interestSortOptionsForTab('jokes');
    const label = options.find((o) => o.id === 'label')!;
    const rows: CategoryInterestRow[] = [
      {
        id: 'b',
        label: 'Winter',
        is_seasonal: false,
        start_month: null,
        start_day: null,
        end_month: null,
        end_day: null,
        category_prompt: null,
        min_jokes: 1,
        max_jokes: 5,
      },
      {
        id: 'a',
        label: 'Animals',
        is_seasonal: false,
        start_month: null,
        start_day: null,
        end_month: null,
        end_day: null,
        category_prompt: null,
        min_jokes: 1,
        max_jokes: 5,
      },
    ];
    expect(sortByOption(rows, label)[0]!.label).toBe('Animals');
  });
});

describe('interestSortToolbarForTab', () => {
  it('includes labels for locations and jokes', () => {
    const locToolbar = interestSortToolbarForTab('locations');
    expect(locToolbar.some((t) => t.label === 'Name')).toBe(true);
    const jokesToolbar = interestSortToolbarForTab('jokes');
    expect(jokesToolbar.some((t) => t.label === 'Label')).toBe(true);
  });

  it('toolbar ids match sort option ids', () => {
    for (const tab of tabs) {
      const toolbar = interestSortToolbarForTab(tab);
      const options = interestSortOptionsForTab(tab);
      expect(toolbar.map((t) => t.id)).toEqual(options.map((o) => o.id));
    }
  });
});
