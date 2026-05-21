import { describe, expect, it, vi } from 'vitest';
import {
  buildIcalCalendarConfigJson,
  icalConfigReady,
  isValidIcalFeedUrl,
  mergeFeedIntoList,
  parseIcalCalendarConfig,
} from './icalCalendarConfig';

describe('icalCalendarConfig', () => {
  it('parses feeds with categoryId and generates id when missing', () => {
    vi.stubGlobal('crypto', { randomUUID: () => 'generated-id' });
    const state = parseIcalCalendarConfig({
      feeds: [
        {
          url: 'https://example.com/a.ics',
          label: 'Work',
          categoryId: 'work',
        },
        {
          id: 'keep-me',
          url: 'https://example.com/b.ics',
          categoryIds: ['personal'],
        },
      ],
    });
    expect(state.feeds).toHaveLength(2);
    expect(state.feeds[0]).toMatchObject({
      id: 'generated-id',
      url: 'https://example.com/a.ics',
      label: 'Work',
      categoryId: 'work',
    });
    expect(state.feeds[1]).toMatchObject({
      id: 'keep-me',
      url: 'https://example.com/b.ics',
      categoryId: 'personal',
    });
    vi.unstubAllGlobals();
  });

  it('parses legacy category field', () => {
    const state = parseIcalCalendarConfig({
      feeds: [{ id: 'x', url: 'https://x/y.ics', category: 'school' }],
    });
    expect(state.feeds[0].categoryId).toBe('school');
  });

  it('builds config with fixed 30-day sync window and enabled feeds', () => {
    const built = buildIcalCalendarConfigJson({
      feeds: [
        { id: 'a', url: 'https://x/a.ics', categoryId: 'work', label: 'A' },
        { id: 'b', url: 'https://x/b.ics', categoryId: 'home' },
      ],
    });
    expect(built.pastDays).toBe(30);
    expect(built.futureDays).toBe(30);
    expect(built.feeds).toEqual([
      {
        id: 'a',
        url: 'https://x/a.ics',
        categoryId: 'work',
        label: 'A',
        enabled: true,
      },
      { id: 'b', url: 'https://x/b.ics', categoryId: 'home', enabled: true },
    ]);
  });

  it('icalConfigReady requires feeds with url and category', () => {
    expect(icalConfigReady({ feeds: [] })).toBe(false);
    expect(
      icalConfigReady({
        feeds: [{ id: 'a', url: 'https://x/a.ics', categoryId: '' }],
      }),
    ).toBe(false);
    expect(
      icalConfigReady({
        feeds: [{ id: 'a', url: 'https://x/a.ics', categoryId: 'work' }],
      }),
    ).toBe(true);
  });

  it('mergeFeedIntoList replaces same id', () => {
    const merged = mergeFeedIntoList(
      [{ id: 'a', url: 'https://old.ics', categoryId: 'x' }],
      { id: 'a', url: 'https://new.ics', categoryId: 'y', label: 'New' },
    );
    expect(merged).toHaveLength(1);
    expect(merged[0].url).toBe('https://new.ics');
    expect(merged[0].label).toBe('New');
  });

  it('isValidIcalFeedUrl accepts http(s) and webcal', () => {
    expect(isValidIcalFeedUrl('https://calendar.example.com/feed.ics')).toBe(true);
    expect(isValidIcalFeedUrl('webcal://calendar.example.com/feed.ics')).toBe(true);
    expect(isValidIcalFeedUrl('not-a-url')).toBe(false);
    expect(isValidIcalFeedUrl('')).toBe(false);
  });
});
