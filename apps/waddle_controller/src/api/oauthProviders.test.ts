import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { SavedDisplay } from '@/storage/displays';
import { listOAuthProviders, putOAuthProviderClientId } from './oauthProviders';

const display = { id: 'd1', name: 'Test', baseUrl: 'http://127.0.0.1:1' } as SavedDisplay;

vi.mock('./client', () => ({
  apiJson: vi.fn(),
  apiFetch: vi.fn(),
}));

import { apiFetch, apiJson } from './client';

describe('oauthProviders api', () => {
  beforeEach(() => {
    vi.mocked(apiJson).mockReset();
    vi.mocked(apiFetch).mockReset();
  });

  it('lists oauth providers', async () => {
    vi.mocked(apiJson).mockResolvedValue({
      items: [{ id: 'google', label: 'Google', account_type: 'google', client_id_configured: true }],
    });
    const items = await listOAuthProviders(display);
    expect(items).toHaveLength(1);
    expect(apiJson).toHaveBeenCalledWith(display, '/v1/oauth-providers');
  });

  it('puts oauth provider client id', async () => {
    vi.mocked(apiFetch).mockResolvedValue(new Response('{}'));
    await putOAuthProviderClientId(display, 'google', 'client-id');
    expect(apiFetch).toHaveBeenCalledWith(
      display,
      '/v1/oauth-providers/google/client-id',
      expect.objectContaining({ method: 'PUT' }),
    );
  });
});
