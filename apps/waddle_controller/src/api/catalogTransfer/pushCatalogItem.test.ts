import { beforeEach, describe, expect, it, vi } from 'vitest';

vi.mock('./listCatalogItems', () => ({
  catalogItemExists: vi.fn(),
}));

vi.mock('./remapOverlayBlobKeys', () => ({
  remapOverlayBlobKeys: vi.fn(async (_s, _t, cfg) => cfg),
}));

vi.mock('@/api/client', () => ({
  apiFetch: vi.fn(),
  ApiError: class ApiError extends Error {
    constructor(
      message: string,
      public status: number,
    ) {
      super(message);
      this.name = 'ApiError';
    }
  },
}));

import { apiFetch } from '@/api/client';
import { catalogItemExists } from './listCatalogItems';
import { pushCatalogItem } from './pushCatalogItem';

const source = { id: 'd-src', label: 'Source', baseUrl: 'https://src.test' };
const target = { id: 'd-tgt', label: 'Target', baseUrl: 'https://tgt.test' };

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

const overlayPayload = {
  kind: 'overlay' as const,
  id: 'hearts',
  overlay_type: 'hearts_rain',
  label: 'Hearts',
  config_json: {},
};

describe('pushCatalogItem', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(apiFetch).mockResolvedValue(new Response('{}', { status: 200 }));
  });

  it('skips when item exists and policy is skip', async () => {
    vi.mocked(catalogItemExists).mockResolvedValue(true);
    const result = await pushCatalogItem({
      source,
      target,
      payload: screenPayload,
      policy: 'skip',
    });
    expect(result.status).toBe('skipped');
    expect(apiFetch).not.toHaveBeenCalled();
  });

  it('patches screen when overwrite and exists', async () => {
    vi.mocked(catalogItemExists).mockResolvedValue(true);
    const result = await pushCatalogItem({
      source,
      target,
      payload: screenPayload,
      policy: 'overwrite',
    });
    expect(result.status).toBe('updated');
    expect(apiFetch).toHaveBeenCalledWith(
      target,
      '/v1/screens/news',
      expect.objectContaining({ method: 'PATCH' }),
    );
  });

  it('posts screen with new id', async () => {
    vi.mocked(catalogItemExists).mockResolvedValue(false);
    const result = await pushCatalogItem({
      source,
      target,
      payload: screenPayload,
      policy: 'new_id',
      newId: 'news_copy',
    });
    expect(result.status).toBe('created');
    expect(apiFetch).toHaveBeenCalledWith(
      target,
      '/v1/screens',
      expect.objectContaining({
        method: 'POST',
        body: expect.stringContaining('"id":"news_copy"'),
      }),
    );
  });

  it('fails new_id when target id already taken', async () => {
    vi.mocked(catalogItemExists).mockResolvedValue(true);
    const result = await pushCatalogItem({
      source,
      target,
      payload: screenPayload,
      policy: 'new_id',
      newId: 'taken',
    });
    expect(result.status).toBe('failed');
    expect(apiFetch).not.toHaveBeenCalled();
  });

  it('patches overlay when overwrite and exists', async () => {
    vi.mocked(catalogItemExists).mockResolvedValue(true);
    const result = await pushCatalogItem({
      source,
      target,
      payload: overlayPayload,
      policy: 'overwrite',
    });
    expect(result.status).toBe('updated');
    expect(apiFetch).toHaveBeenCalledWith(
      target,
      '/v1/display/overlays/hearts',
      expect.objectContaining({ method: 'PATCH' }),
    );
  });

  it('posts overlay as created when target id is free', async () => {
    vi.mocked(catalogItemExists).mockResolvedValue(false);
    const result = await pushCatalogItem({
      source,
      target,
      payload: overlayPayload,
      policy: 'overwrite',
    });
    expect(result.status).toBe('created');
    expect(apiFetch).toHaveBeenCalledWith(
      target,
      '/v1/display/overlays',
      expect.objectContaining({ method: 'POST' }),
    );
  });
});
