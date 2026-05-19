import { describe, expect, it, vi, beforeEach } from 'vitest';
import { fetchAndCacheConfigSchemas } from './configSchemas';
import { loadConfigSchemas } from '@/storage/configSchemaCache';

vi.mock('@/api/client', () => ({
  apiJson: vi.fn(),
}));

import { apiJson } from '@/api/client';

const display = { id: 'd1', label: 'Lab', baseUrl: 'https://display.test' };

const bundle = {
  screen_types: [],
  ticker_tape_types: [],
  overlay_types: [],
  integration_types: [],
};

describe('fetchAndCacheConfigSchemas', () => {
  beforeEach(() => {
    localStorage.clear();
    vi.mocked(apiJson).mockReset();
  });

  it('fetches bundled schemas and persists them', async () => {
    vi.mocked(apiJson).mockResolvedValue(bundle);
    const result = await fetchAndCacheConfigSchemas(display);
    expect(apiJson).toHaveBeenCalledWith(display, '/v1/meta/config-schemas');
    expect(result).toEqual(bundle);
    expect(loadConfigSchemas('d1')).toEqual(bundle);
  });
});
