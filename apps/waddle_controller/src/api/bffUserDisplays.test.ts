import { describe, expect, it, vi } from 'vitest';
import {
  deleteUserDisplay,
  fetchUserDisplays,
  setActiveUserDisplay,
  upsertUserDisplay,
} from './bffUserDisplays';

describe('bffUserDisplays', () => {
  it('calls BFF user-displays endpoints', async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce(
        new Response(JSON.stringify({ displays: [] }), { status: 200 }),
      )
      .mockResolvedValueOnce(
        new Response(JSON.stringify({ display: { displayId: 'd1' } }), { status: 200 }),
      )
      .mockResolvedValueOnce(
        new Response(JSON.stringify({ display: { displayId: 'd1' } }), { status: 200 }),
      )
      .mockResolvedValueOnce(new Response(JSON.stringify({ ok: true }), { status: 200 }));
    vi.stubGlobal('fetch', fetchMock);

    await fetchUserDisplays();
    await upsertUserDisplay({
      displayId: 'd1',
      label: 'L',
      baseUrl: 'https://127.0.0.1:8787',
      clientIdentifier: 'wc',
      adoptedRole: 'admin',
      apiKey: 'key',
      permissions: [],
    });
    await setActiveUserDisplay('d1');
    await deleteUserDisplay('d1');

    expect(fetchMock).toHaveBeenCalledWith(
      '/bff/v1/user-displays',
      expect.objectContaining({ credentials: 'include' }),
    );
  });
});
