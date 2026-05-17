import { beforeEach, describe, expect, it, vi } from 'vitest';
import { issueApiClient, listApiClients, revokeApiClient } from '@/api/apiClients';
import type { SavedDisplay } from '@/storage/displays';

const display: SavedDisplay = {
  id: 'd1',
  baseUrl: 'https://display.test',
  label: 'Display',
};

vi.mock('@/api/client', () => ({
  apiJson: vi.fn(),
  apiFetch: vi.fn(),
}));

import { apiFetch, apiJson } from '@/api/client';

describe('apiClients', () => {
  beforeEach(() => {
    vi.mocked(apiJson).mockReset();
    vi.mocked(apiFetch).mockReset();
  });

  it('listApiClients returns items', async () => {
    vi.mocked(apiJson).mockResolvedValue({
      items: [
        {
          id: 'c1',
          identifier: 'wc-host',
          role: 'admin',
          masked_api_key: 'wd_••••••••abcd',
          created_at_ms: 1,
          updated_at_ms: 2,
        },
      ],
    });

    const items = await listApiClients(display);
    expect(items).toHaveLength(1);
    expect(apiJson).toHaveBeenCalledWith(display, '/v1/adoption/clients');
  });

  it('issueApiClient posts identifier and role', async () => {
    vi.mocked(apiJson).mockResolvedValue({
      api_key: 'wd_secret',
      identifier: 'new-client',
      role: 'viewer',
      permissions: ['telemetry.read'],
    });

    const result = await issueApiClient(display, {
      identifier: 'new-client',
      role: 'viewer',
    });
    expect(result.api_key).toBe('wd_secret');
    expect(apiJson).toHaveBeenCalledWith(
      display,
      '/v1/adoption/clients',
      expect.objectContaining({
        method: 'POST',
        body: JSON.stringify({ identifier: 'new-client', role: 'viewer' }),
      }),
    );
  });

  it('revokeApiClient deletes by id', async () => {
    vi.mocked(apiFetch).mockResolvedValue(new Response('{}', { status: 200 }));
    await revokeApiClient(display, 'client-1');
    expect(apiFetch).toHaveBeenCalledWith(
      display,
      '/v1/adoption/clients/client-1',
      { method: 'DELETE' },
    );
  });
});
