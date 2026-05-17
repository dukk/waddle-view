import { beforeEach, describe, expect, it, vi } from 'vitest';
import { ApiError, apiFetch, fetchBlobObjectUrl, hasPermission } from './client';
import { saveSession, type DisplaySession } from '@/storage/sessions';
import type { SavedDisplay } from '@/storage/displays';

const display: SavedDisplay = {
  id: 'd-test',
  label: 'Test',
  baseUrl: 'https://display.test',
};

const session: DisplaySession = {
  apiKey: 'secret-api-key',
  expiresAtMs: Date.now() + 60_000,
  identifier: 'controller-test',
  role: 'operator',
  permissions: ['telemetry.read', 'navigation.control'],
};

describe('api client', () => {
  beforeEach(() => {
    sessionStorage.clear();
    saveSession(display.id, session);
  });

  it('hasPermission checks session permissions', () => {
    expect(hasPermission(session, 'telemetry.read')).toBe(true);
    expect(hasPermission(session, 'users.manage')).toBe(false);
    expect(hasPermission(null, 'telemetry.read')).toBe(false);
  });

  it('apiFetch attaches bearer token and normalizes path', async () => {
    const fetchMock = vi.fn().mockResolvedValue(new Response('{}', { status: 200 }));
    vi.stubGlobal('fetch', fetchMock);

    await apiFetch(display, 'v1/screens');

    expect(fetchMock).toHaveBeenCalledWith(
      'https://display.test/v1/screens',
      expect.objectContaining({
        headers: expect.any(Headers),
      }),
    );
    const headers = fetchMock.mock.calls[0]![1]!.headers as Headers;
    expect(headers.get('Authorization')).toBe('Bearer secret-api-key');
  });

  it('apiFetch throws ApiError when not signed in', async () => {
    sessionStorage.clear();
    await expect(apiFetch(display, '/v1/screens')).rejects.toMatchObject({
      name: 'ApiError',
      status: 401,
    });
  });

  it('apiFetch throws ApiError on HTTP errors', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response('nope', { status: 403 })));
    await expect(apiFetch(display, '/v1/screens')).rejects.toEqual(
      expect.objectContaining({ status: 403 }),
    );
    expect(new ApiError('msg', 500).name).toBe('ApiError');
  });

  it('fetchBlobObjectUrl returns object URL for blobs', async () => {
    const blob = new Uint8Array([1, 2, 3]);
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(
        new Response(blob, {
          status: 200,
          headers: { 'Content-Type': 'image/png' },
        }),
      ),
    );
    const createObjectURL = vi.fn().mockReturnValue('blob:mock');
    Object.defineProperty(URL, 'createObjectURL', { value: createObjectURL, configurable: true });

    const url = await fetchBlobObjectUrl(display, 'blob-key');
    expect(url).toBe('blob:mock');
    expect(createObjectURL).toHaveBeenCalled();
  });

  it('fetchBlobObjectUrl returns null without session or on failure', async () => {
    sessionStorage.clear();
    expect(await fetchBlobObjectUrl(display, 'k')).toBeNull();

    saveSession(display.id, session);
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response(null, { status: 404 })));
    expect(await fetchBlobObjectUrl(display, 'k')).toBeNull();
  });
});
