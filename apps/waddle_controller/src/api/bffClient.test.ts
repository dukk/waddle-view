import { afterEach, describe, expect, it, vi } from 'vitest';
import { bffFetch, BffError, bffJson } from '@/api/bffClient';

describe('bffClient', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('bffJson parses success', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => ({ authEnabled: false }),
      }),
    );
    const data = await bffJson<{ authEnabled: boolean }>('/status');
    expect(data.authEnabled).toBe(false);
    expect(fetch).toHaveBeenCalledWith(
      '/bff/v1/status',
      expect.objectContaining({ credentials: 'include' }),
    );
  });

  it('throws BffError with code on failure', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: false,
        status: 401,
        statusText: 'Unauthorized',
        json: async () => ({ error: 'Invalid credentials', code: 'invalid_credentials' }),
      }),
    );
    await expect(bffFetch('/auth/login')).rejects.toMatchObject({
      name: 'BffError',
      status: 401,
      code: 'invalid_credentials',
    } satisfies Partial<BffError>);
  });
});
