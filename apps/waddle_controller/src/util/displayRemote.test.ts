import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { SavedDisplay } from '@/storage/displays';
import { saveSession } from '@/storage/sessions';
import { dismissActiveDisplayAlert, postDisplayNavigation } from '@/util/displayRemote';

const display: SavedDisplay = {
  id: 'd1',
  baseUrl: 'https://127.0.0.1:8787',
  label: 'Kiosk',
};

describe('displayRemote', () => {
  beforeEach(() => {
    localStorage.clear();
    saveSession(display.id, {
      apiKey: 'key',
      identifier: 'op',
      role: 'operator',
      permissions: ['navigation.control', 'alerts.write'],
      expiresAtMs: Date.now() + 60_000,
    });
  });

  it('postDisplayNavigation posts surface and direction', async () => {
    const fetch = vi.fn().mockResolvedValue(new Response('{}', { status: 200 }));
    vi.stubGlobal('fetch', fetch);
    expect(await postDisplayNavigation(display, 'screen', 'forward')).toBeNull();
    expect(fetch).toHaveBeenCalledOnce();
    const [url, init] = fetch.mock.calls[0] as [string, RequestInit];
    expect(url).toContain('/v1/display/navigation');
    expect(init?.method).toBe('POST');
    expect(init?.body).toBe(JSON.stringify({ surface: 'screen', direction: 'forward' }));
  });

  it('dismissActiveDisplayAlert deletes the active alert id', async () => {
    const fetch = vi
      .fn()
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            items: [
              { id: 1, priority: 1, created_at_ms: 1 },
              { id: 2, priority: 5, created_at_ms: 2 },
            ],
          }),
          { status: 200, headers: { 'Content-Type': 'application/json' } },
        ),
      )
      .mockResolvedValueOnce(new Response('{}', { status: 200 }));
    vi.stubGlobal('fetch', fetch);
    expect(await dismissActiveDisplayAlert(display)).toBeNull();
    expect(fetch).toHaveBeenCalledTimes(2);
    const [deleteUrl, deleteInit] = fetch.mock.calls[1] as [string, RequestInit];
    expect(deleteUrl).toContain('/v1/alerts/2');
    expect(deleteInit?.method).toBe('DELETE');
  });

  it('dismissActiveDisplayAlert reports when nothing is active', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(
        new Response(JSON.stringify({ items: [] }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        }),
      ),
    );
    expect(await dismissActiveDisplayAlert(display)).toBe('No active alert to dismiss');
  });
});
