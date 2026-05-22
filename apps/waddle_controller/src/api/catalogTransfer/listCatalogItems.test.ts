import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { SavedDisplay } from '@/storage/displays';
import { catalogItemExists, listCatalogItems } from './listCatalogItems';

const display = { id: 'd1', label: 'Test', baseUrl: 'http://127.0.0.1:1' } as SavedDisplay;

vi.mock('@/api/client', () => ({
  apiJson: vi.fn(),
}));

import { apiJson } from '@/api/client';

describe('listCatalogItems', () => {
  beforeEach(() => {
    vi.mocked(apiJson).mockReset();
  });

  it('listCatalogItems sorts labels and catalogItemExists finds id', async () => {
    vi.mocked(apiJson).mockResolvedValue({
      items: [
        { id: 'b', label: 'Bravo', screen_type: 'news' },
        { id: 'a', label: 'Alpha', screen_type: 'news' },
      ],
    });
    const items = await listCatalogItems('screen', display);
    expect(items.map((i) => i.label)).toEqual(['Alpha', 'Bravo']);
    expect(await catalogItemExists('screen', display, 'a')).toBe(true);
    expect(await catalogItemExists('screen', display, 'missing')).toBe(false);
  });
});
