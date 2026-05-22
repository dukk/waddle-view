import { describe, it, expect, vi, beforeEach } from 'vitest';
import { fetchRemoteViewInfo, createRemoteViewSession } from '@/api/displayRemoteView';
import type { SavedDisplay } from '@/storage/displays';

const display: SavedDisplay = { id: 'd1', label: 'L', baseUrl: 'https://h:8787' };

vi.mock('@/api/client', () => ({
  apiJson: vi.fn(),
  apiFetch: vi.fn(),
  sessionForDisplay: vi.fn(),
}));

import { apiJson } from '@/api/client';

describe('displayRemoteView', () => {
  beforeEach(() => {
    vi.mocked(apiJson).mockReset();
  });

  it('fetchRemoteViewInfo calls display API', async () => {
    vi.mocked(apiJson).mockResolvedValue({
      configured: true,
      enabled: true,
      host: '127.0.0.1',
      port: 6080,
      path: '/',
      password_configured: false,
    });
    const info = await fetchRemoteViewInfo(display);
    expect(apiJson).toHaveBeenCalledWith(display, '/v1/display/remote-view');
    expect(info.configured).toBe(true);
  });

  it('createRemoteViewSession posts session endpoint', async () => {
    vi.mocked(apiJson).mockResolvedValue({ ticket: 't1', expires_at_ms: 1 });
    const session = await createRemoteViewSession(display);
    expect(apiJson).toHaveBeenCalledWith(
      display,
      '/v1/display/remote-view/session',
      expect.objectContaining({ method: 'POST' }),
    );
    expect(session.ticket).toBe('t1');
  });
});
