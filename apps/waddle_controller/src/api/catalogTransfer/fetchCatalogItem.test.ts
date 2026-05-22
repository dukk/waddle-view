import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { SavedDisplay } from '@/storage/displays';
import { fetchCatalogItem } from './fetchCatalogItem';

const display = { id: 'd1', label: 'Test', baseUrl: 'http://127.0.0.1:1' } as SavedDisplay;

vi.mock('@/api/client', () => ({
  apiJson: vi.fn(),
}));

import { apiJson } from '@/api/client';

describe('fetchCatalogItem', () => {
  beforeEach(() => {
    vi.mocked(apiJson).mockReset();
  });

  it('returns parsed payload when id matches', async () => {
    vi.mocked(apiJson).mockResolvedValue({
      items: [{ id: 'screen-1', label: 'News', screen_type: 'news', config_json: '{}' }],
    });
    const payload = await fetchCatalogItem('screen', display, 'screen-1');
    expect(payload?.kind).toBe('screen');
    expect(payload && 'label' in payload && payload.label).toBe('News');
  });

  it('returns null when id is not in list', async () => {
    vi.mocked(apiJson).mockResolvedValue({ items: [{ id: 'other', label: 'X', screen_type: 'news' }] });
    const payload = await fetchCatalogItem('screen', display, 'missing');
    expect(payload).toBeNull();
  });
});
