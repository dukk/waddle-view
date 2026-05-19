import { beforeEach, describe, expect, it, vi } from 'vitest';

vi.mock('./fetchCatalogItem', () => ({
  fetchCatalogItem: vi.fn(),
}));

vi.mock('./pushCatalogItem', () => ({
  pushCatalogItem: vi.fn(),
}));

import { fetchCatalogItem } from './fetchCatalogItem';
import { pushCatalogItem } from './pushCatalogItem';
import { transferCatalogItem } from './transferCatalogItem';

const source = { id: 'd-src', label: 'Source', baseUrl: 'https://src.test' };
const targetA = { id: 'd-a', label: 'A', baseUrl: 'https://a.test' };
const targetB = { id: 'd-b', label: 'B', baseUrl: 'https://b.test' };

const screenPayload = {
  kind: 'screen' as const,
  id: 'news',
  screen_type: 'rss',
  label: 'News',
  description: '',
  config_json: {},
  min_dwell_seconds: 8,
  max_dwell_seconds: 15,
  frequency_weight: 100,
  min_gap_between_shows_seconds: 0,
  min_placements_per_program: 0,
  max_placements_per_program: null,
  data_key: '',
};

describe('transferCatalogItem', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('reports sourceMissing when item not found', async () => {
    vi.mocked(fetchCatalogItem).mockResolvedValue(null);
    const out = await transferCatalogItem({
      kind: 'screen',
      source,
      targets: [targetA],
      itemId: 'missing',
      policy: 'skip',
    });
    expect(out.sourceMissing).toBe(true);
    expect(out.results).toEqual([]);
    expect(pushCatalogItem).not.toHaveBeenCalled();
  });

  it('pushes to each target', async () => {
    vi.mocked(fetchCatalogItem).mockResolvedValue(screenPayload);
    vi.mocked(pushCatalogItem)
      .mockResolvedValueOnce({
        displayId: 'd-a',
        displayLabel: 'A',
        status: 'created',
      })
      .mockResolvedValueOnce({
        displayId: 'd-b',
        displayLabel: 'B',
        status: 'skipped',
        message: 'Already exists',
      });

    const out = await transferCatalogItem({
      kind: 'screen',
      source,
      targets: [targetA, targetB],
      itemId: 'news',
      policy: 'skip',
    });

    expect(pushCatalogItem).toHaveBeenCalledTimes(2);
    expect(out.results).toHaveLength(2);
    expect(out.results[0]?.status).toBe('created');
    expect(out.results[1]?.status).toBe('skipped');
  });
});
