import { beforeEach, describe, expect, it, vi } from 'vitest';
import { fetchDisplaySettings, putDisplaySettings } from '@/api/displaySettings';
import type { SavedDisplay } from '@/storage/displays';

const display: SavedDisplay = {
  id: 'd1',
  label: 'Test',
  baseUrl: 'http://127.0.0.1:8080',
};

vi.mock('@/api/client', () => ({
  apiJson: vi.fn(),
}));

import { apiJson } from '@/api/client';

describe('displaySettings api', () => {
  beforeEach(() => {
    vi.mocked(apiJson).mockReset();
  });

  it('fetchDisplaySettings GETs /v1/display/settings', async () => {
    const body = {
      display_theme_id: 'navy_coral',
      controller_time_format: '12h',
      controller_date_order: 'mdy',
    };
    vi.mocked(apiJson).mockResolvedValue(body);

    const result = await fetchDisplaySettings(display);
    expect(result).toEqual(body);
    expect(apiJson).toHaveBeenCalledWith(display, '/v1/display/settings');
  });

  it('putDisplaySettings PUTs partial body', async () => {
    vi.mocked(apiJson).mockResolvedValue({});

    await putDisplaySettings(display, { controller_time_format: '24h' });
    expect(apiJson).toHaveBeenCalledWith(display, '/v1/display/settings', {
      method: 'PUT',
      body: JSON.stringify({ controller_time_format: '24h' }),
    });
  });

});
