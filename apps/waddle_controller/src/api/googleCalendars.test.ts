import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { SavedDisplay } from '@/storage/displays';
import { fetchGoogleCalendars } from './googleCalendars';

const display = { id: 'd1', name: 'Test', baseUrl: 'http://127.0.0.1:1' } as SavedDisplay;

vi.mock('./client', () => ({
  apiJson: vi.fn(),
}));

import { apiJson } from './client';

describe('googleCalendars api', () => {
  beforeEach(() => {
    vi.mocked(apiJson).mockReset();
  });

  it('fetches calendars for a Google account', async () => {
    vi.mocked(apiJson).mockResolvedValue({
      items: [{ id: 'primary', name: 'Primary' }],
    });
    const items = await fetchGoogleCalendars(display, 'personal');
    expect(items).toHaveLength(1);
    expect(apiJson).toHaveBeenCalledWith(
      display,
      '/v1/integration-accounts/personal/google/calendars',
    );
  });
});
