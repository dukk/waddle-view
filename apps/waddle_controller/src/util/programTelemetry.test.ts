import { describe, expect, it } from 'vitest';
import {
  buildSlideCardModel,
  collectSlideContentIds,
  collectWeatherLocationIds,
  formatDwell,
  parseLayoutWidgets,
  programTimestamp,
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

  it('uses curated choice labels for RSS', () => {
    const model = buildSlideCardModel(
      {
        screen_id: 's2',
        dwell_ms: 1000,
        layout_json: {
          widgets: [{ type: 'rss_article', slot: 'rss', config: { feedId: 'f1' } }],
        },
        random_choices: { rss_rss_article: 'article-9' },
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
            { type: 'pexels_photo', slot: 'p', config: {} },
            { type: 'joke', slot: 'j', config: {} },
          ],
        },
        random_choices: { p_pexels_photo: 'photo1', j_joke: 'joke1', j_joke_dup: 'ignored' },
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
