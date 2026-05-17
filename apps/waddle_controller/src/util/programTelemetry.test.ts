import { describe, expect, it } from 'vitest';
import {
  buildSlideCardModel,
  collectSlideContentIds,
  collectWeatherLocationIds,
  formatDwell,
  paginateList,
  parseLayoutWidgets,
  programAtMs,
  programTimestamp,
  screenTypePreviewKind,
  slideScreenPreviewKind,
  sortProgramsByAtMsDesc,
  tickerTapeSummary,
} from './programTelemetry';

describe('parseLayoutWidgets', () => {
  it('parses widget arrays from objects', () => {
    const widgets = parseLayoutWidgets({
      widgets: [{ type: 'static_text', slot: 'main', config: { text: 'Hi' } }],
    });
    expect(widgets).toEqual([
      { type: 'static_text', slot: 'main', config: { text: 'Hi' } },
    ]);
  });

  it('parses JSON string layouts', () => {
    const widgets = parseLayoutWidgets(
      JSON.stringify({ widgets: [{ type: 'weather', slot: 'w', config: { locationId: 'loc1' } }] }),
    );
    expect(widgets[0]?.type).toBe('weather');
  });

  it('returns empty for invalid input', () => {
    expect(parseLayoutWidgets(null)).toEqual([]);
    expect(parseLayoutWidgets('not-json')).toEqual([]);
    expect(parseLayoutWidgets({ widgets: 'nope' })).toEqual([]);
  });
});

describe('formatDwell', () => {
  it('formats sub-second, seconds, and minutes', () => {
    expect(formatDwell(500)).toBe('500 ms');
    expect(formatDwell(2500)).toBe('2.5 s');
    expect(formatDwell(90_000)).toBe('1m 30s');
    expect(formatDwell('bad')).toBe('—');
  });
});

describe('programTimestamp', () => {
  it('formats finite epoch values', () => {
    const label = programTimestamp(1_700_000_000_000);
    expect(label).not.toBe('Unknown time');
  });

  it('returns Unknown time for invalid values', () => {
    expect(programTimestamp('nope')).toBe('Unknown time');
  });
});

describe('buildSlideCardModel', () => {
  it('summarizes static text and dwell', () => {
    const model = buildSlideCardModel(
      {
        screen_id: 's1',
        screen_type: 'layout',
        dwell_ms: 3000,
        layout_json: {
          widgets: [{ type: 'static_text', slot: 'a', config: { text: 'Hello' } }],
        },
        random_choices: {},
      },
      0,
    );
    expect(model.screenId).toBe('s1');
    expect(model.dwellLabel).toBe('3 s');
    expect(model.summaries[0]?.headline).toBe('Hello');
  });

  it('summarizes web_page with host and url', () => {
    const model = buildSlideCardModel(
      {
        screen_id: 'wp',
        screen_type: 'web_page',
        dwell_ms: 15000,
        layout_json: {
          widgets: [
            {
              type: 'web_page',
              slot: 'main',
              config: { url: 'https://status.example.com/board' },
            },
          ],
        },
        random_choices: {},
      },
      0,
    );
    expect(model.summaries[0]?.headline).toBe('Web · status.example.com');
    expect(model.summaries[0]?.sub).toBe('https://status.example.com/board');
  });

  it('uses curated choice labels for RSS', () => {
    const model = buildSlideCardModel(
      {
        screen_id: 's2',
        dwell_ms: 1000,
        layout_json: {
          widgets: [{ type: 'news', slot: 'rss', config: { feedId: 'f1' } }],
        },
        random_choices: { rss_news: 'article-9' },
      },
      1,
    );
    expect(model.summaries[0]?.headline).toContain('article-9');
  });
});

describe('collectSlideContentIds', () => {
  it('collects unique content ids from random choices', () => {
    const model = buildSlideCardModel(
      {
        screen_id: 's3',
        dwell_ms: 1000,
        layout_json: {
          widgets: [
            { type: 'photo', slot: 'p', config: {} },
            { type: 'joke', slot: 'j', config: {} },
          ],
        },
        random_choices: { p_photo: 'photo1', j_joke: 'joke1', j_joke_dup: 'ignored' },
      },
      0,
    );
    const ids = collectSlideContentIds(model);
    expect(ids.photoIds).toEqual(['photo1']);
    expect(ids.jokeIds).toEqual(['joke1']);
  });
});

describe('collectWeatherLocationIds', () => {
  it('reads locationId and location_id', () => {
    const model = buildSlideCardModel(
      {
        screen_id: 's4',
        dwell_ms: 1000,
        layout_json: {
          widgets: [{ type: 'weather', slot: 'w', config: { location_id: 'chicago' } }],
        },
      },
      0,
    );
    expect(collectWeatherLocationIds(model)).toEqual(['chicago']);
  });
});

describe('programAtMs', () => {
  it('reads numeric and string at_ms', () => {
    expect(programAtMs({ at_ms: 1000 })).toBe(1000);
    expect(programAtMs({ at_ms: '2500' })).toBe(2500);
    expect(programAtMs({})).toBe(0);
  });
});

describe('sortProgramsByAtMsDesc', () => {
  it('orders newest first without mutating input', () => {
    const input = [{ at_ms: 1 }, { at_ms: 3 }, { at_ms: 2 }];
    const sorted = sortProgramsByAtMsDesc(input);
    expect(sorted.map((r) => programAtMs(r))).toEqual([3, 2, 1]);
    expect(input.map((r) => programAtMs(r))).toEqual([1, 3, 2]);
  });
});

describe('paginateList', () => {
  it('returns the requested page slice', () => {
    const all = [1, 2, 3, 4, 5, 6, 7];
    expect(paginateList(all, 0, 3)).toMatchObject({
      items: [1, 2, 3],
      total: 7,
      page: 0,
      pageCount: 3,
    });
    expect(paginateList(all, 1, 3)).toMatchObject({
      items: [4, 5, 6],
      page: 1,
    });
    expect(paginateList(all, 2, 3)).toMatchObject({
      items: [7],
      page: 2,
    });
  });

  it('clamps page when the list is shorter', () => {
    expect(paginateList([1, 2, 3], 5, 2)).toMatchObject({
      items: [3],
      page: 1,
      pageCount: 2,
    });
  });
});

describe('screenTypePreviewKind', () => {
  it('maps catalog screen types including photo and video', () => {
    expect(screenTypePreviewKind('joke')).toBe('joke');
    expect(screenTypePreviewKind('photo')).toBe('photo');
    expect(screenTypePreviewKind('video')).toBe('video');
    expect(screenTypePreviewKind('photo_collage')).toBe('photo_collage');
    expect(screenTypePreviewKind('web_page')).toBeNull();
  });

  it('returns null for unknown types', () => {
    expect(screenTypePreviewKind('')).toBeNull();
    expect(screenTypePreviewKind('layout')).toBeNull();
  });
});

describe('slideScreenPreviewKind', () => {
  it('maps screen_type to preview kinds', () => {
    expect(
      slideScreenPreviewKind(
        buildSlideCardModel({ screen_id: 'a', screen_type: 'digital_clock', layout_json: {} }, 0),
      ),
    ).toBe('clock');
    expect(
      slideScreenPreviewKind(
        buildSlideCardModel({ screen_id: 'b', screen_type: 'stock_quotes', layout_json: {} }, 0),
      ),
    ).toBe('stock');
  });

  it('falls back to widget types on layout screens', () => {
    const model = buildSlideCardModel(
      {
        screen_id: 'c',
        screen_type: 'layout',
        layout_json: {
          widgets: [{ type: 'joke', slot: 'main', config: {} }],
        },
      },
      0,
    );
    expect(slideScreenPreviewKind(model)).toBe('joke');
  });

  it('maps non-media screen types', () => {
    expect(
      slideScreenPreviewKind(
        buildSlideCardModel({ screen_id: 'd', screen_type: 'news', layout_json: {} }, 0),
      ),
    ).toBe('news');
    expect(
      slideScreenPreviewKind(
        buildSlideCardModel({ screen_id: 'e', screen_type: 'wifi', layout_json: {} }, 0),
      ),
    ).toBe('wifi');
  });

  it('returns null for photo and video screen types', () => {
    expect(
      slideScreenPreviewKind(
        buildSlideCardModel({ screen_id: 'f', screen_type: 'photo', layout_json: {} }, 0),
      ),
    ).toBeNull();
    expect(
      slideScreenPreviewKind(
        buildSlideCardModel({ screen_id: 'g', screen_type: 'video', layout_json: {} }, 0),
      ),
    ).toBeNull();
  });
});

describe('tickerTapeSummary', () => {
  it('prefers RSS article titles', () => {
    const summary = tickerTapeSummary({
      kind: 'rss',
      rss: { article_title: 'Headline' },
      body: 'ignored',
    });
    expect(summary).toBe('rss: Headline');
  });

  it('truncates long bodies', () => {
    const body = 'x'.repeat(200);
    const summary = tickerTapeSummary({ kind: 'text', body });
    expect(summary.length).toBeLessThan(body.length + 10);
    expect(summary).toContain('…');
  });
});
