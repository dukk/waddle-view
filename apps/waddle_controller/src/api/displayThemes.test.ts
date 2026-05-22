import { beforeEach, describe, expect, it, vi } from 'vitest';

import {
  createDisplayTheme,
  deleteDisplayTheme,
  fetchDisplayThemes,
  updateDisplayTheme,
} from '@/api/displayThemes';
import { apiJson } from '@/api/client';
import type { SavedDisplay } from '@/storage/displays';

vi.mock('@/api/client', () => ({
  apiJson: vi.fn(),
}));

const display = { id: 'd1', label: 'TV', baseUrl: 'http://x' } as SavedDisplay;

const preview = {
  display: ['#0D1B2A', '#1B263B'],
  primaryContainer: ['#E0E1DD', '#1B263B'],
  secondaryContainer: ['#E0E1DD', '#415A77'],
  accents: ['#83AF84', '#E05C6C', '#FFE356', '#966CB3'],
};

describe('displayThemes api', () => {
  beforeEach(() => {
    vi.mocked(apiJson).mockReset();
  });

  it('fetchDisplayThemes GETs list', async () => {
    vi.mocked(apiJson).mockResolvedValue({
      items: [{ id: 'custom_a', label: 'A', preview }],
    });
    const items = await fetchDisplayThemes(display);
    expect(apiJson).toHaveBeenCalledWith(display, '/v1/display/themes');
    expect(items).toHaveLength(1);
  });

  it('createDisplayTheme POSTs body', async () => {
    vi.mocked(apiJson).mockResolvedValue({ id: 'custom_a', label: 'A', preview });
    await createDisplayTheme(display, { label: 'A', preview });
    expect(apiJson).toHaveBeenCalledWith(
      display,
      '/v1/display/themes',
      expect.objectContaining({ method: 'POST' }),
    );
  });

  it('updateDisplayTheme PATCHes id', async () => {
    vi.mocked(apiJson).mockResolvedValue({ id: 'custom_a', label: 'B', preview });
    await updateDisplayTheme(display, 'custom_a', { label: 'B' });
    expect(apiJson).toHaveBeenCalledWith(
      display,
      '/v1/display/themes/custom_a',
      expect.objectContaining({ method: 'PATCH' }),
    );
  });

  it('deleteDisplayTheme DELETEs id', async () => {
    vi.mocked(apiJson).mockResolvedValue({});
    await deleteDisplayTheme(display, 'custom_a');
    expect(apiJson).toHaveBeenCalledWith(
      display,
      '/v1/display/themes/custom_a',
      expect.objectContaining({ method: 'DELETE' }),
    );
  });
});
