import { describe, expect, it } from 'vitest';
import { parseCatalogPayload } from './parseCatalogItem';

describe('parseCatalogPayload', () => {
  it('parses screen rows', () => {
    const row = parseCatalogPayload('screen', {
      id: 'news',
      screen_type: 'rss',
      label: 'News',
      config_json: '{"feed":"x"}',
      min_dwell_seconds: 10,
      max_dwell_seconds: 20,
      data_key: 'dk1',
    });
    expect(row).toMatchObject({
      kind: 'screen',
      id: 'news',
      screen_type: 'rss',
      label: 'News',
      data_key: 'dk1',
    });
  });

  it('parses overlay rows', () => {
    const row = parseCatalogPayload('overlay', {
      id: 'hearts',
      overlay_type: 'hearts_rain',
      label: 'Hearts',
      config_json: { shapes: ['heart'] },
    });
    expect(row).toMatchObject({
      kind: 'overlay',
      id: 'hearts',
      overlay_type: 'hearts_rain',
    });
  });
});
