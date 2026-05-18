import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { SavedDisplay } from '@/storage/displays';
import { fetchMicrosoftGraphCalendars } from './microsoftGraphCalendars';

const display = { id: 'd1', name: 'Test', baseUrl: 'http://127.0.0.1:1' } as SavedDisplay;

vi.mock('./client', () => ({
  apiJson: vi.fn(),
}));

import { apiJson } from './client';

describe('microsoftGraphCalendars api', () => {
  beforeEach(() => {
    vi.mocked(apiJson).mockReset();
  });

  it('fetches calendars for a Microsoft account', async () => {
    vi.mocked(apiJson).mockResolvedValue({
      items: [{ id: 'cal-1', name: 'Work' }],
    });
    const items = await fetchMicrosoftGraphCalendars(display, 'work');
    expect(items).toHaveLength(1);
    expect(apiJson).toHaveBeenCalledWith(
      display,
      '/v1/integration-accounts/work/microsoft-graph/calendars',
    );
  });
});
