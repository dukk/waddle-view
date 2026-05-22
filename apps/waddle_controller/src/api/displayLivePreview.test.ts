import { describe, it, expect, vi, beforeEach } from 'vitest';
import { fetchLivePreviewInfo, createLivePreviewSession } from '@/api/displayLivePreview';
import type { SavedDisplay } from '@/storage/displays';

const display: SavedDisplay = { id: 'd1', label: 'L', baseUrl: 'https://h:8787' };

vi.mock('@/api/client', () => ({
  apiJson: vi.fn(),
  apiFetch: vi.fn(),
  sessionForDisplay: vi.fn(),
}));

import { apiJson } from '@/api/client';

describe('displayLivePreview', () => {
  beforeEach(() => {
    vi.mocked(apiJson).mockReset();
  });

  it('fetchLivePreviewInfo calls display API', async () => {
    vi.mocked(apiJson).mockResolvedValue({
      configured: true,
      enabled: true,
      fps: 10,
      width: 1280,
      quality: 75,
    });
    const info = await fetchLivePreviewInfo(display);
    expect(apiJson).toHaveBeenCalledWith(display, '/v1/display/live-preview');
    expect(info.configured).toBe(true);
  });

  it('createLivePreviewSession posts session endpoint', async () => {
    vi.mocked(apiJson).mockResolvedValue({ ticket: 't1', expires_at_ms: 1 });
    const session = await createLivePreviewSession(display);
    expect(apiJson).toHaveBeenCalledWith(
      display,
      '/v1/display/live-preview/session',
      expect.objectContaining({ method: 'POST' }),
    );
    expect(session.ticket).toBe('t1');
  });
});
