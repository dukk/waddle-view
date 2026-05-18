import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { SavedDisplay } from '@/storage/displays';
import {
  createIntegrationAccount,
  fetchIntegrationAccounts,
  patchIntegrationAccount,
  putIntegrationAccountSecret,
  probeIntegrationAccountOAuth,
  requestIntegrationAccountSignIn,
} from './integrationAccounts';

const display = { id: 'd1', name: 'Test', baseUrl: 'http://127.0.0.1:1' } as SavedDisplay;

vi.mock('./client', () => ({
  apiJson: vi.fn(),
  apiFetch: vi.fn(),
}));

import { apiFetch, apiJson } from './client';

describe('integrationAccounts api', () => {
  beforeEach(() => {
    vi.mocked(apiJson).mockReset();
    vi.mocked(apiFetch).mockReset();
  });

  it('fetches integration accounts', async () => {
    vi.mocked(apiJson).mockResolvedValue({ items: [], account_types: [], requirements: [] });
    await fetchIntegrationAccounts(display);
    expect(apiJson).toHaveBeenCalledWith(display, '/v1/integration-accounts');
  });

  it('creates integration account', async () => {
    vi.mocked(apiJson).mockResolvedValue({ account_id: 'work' });
    const res = await createIntegrationAccount(display, {
      account_type: 'google',
      account_key: 'work',
    });
    expect(res.account_id).toBe('work');
    expect(apiJson).toHaveBeenCalledWith(
      display,
      '/v1/integration-accounts',
      expect.objectContaining({ method: 'POST' }),
    );
  });

  it('patches integration account label', async () => {
    vi.mocked(apiFetch).mockResolvedValue(new Response('{}'));
    await patchIntegrationAccount(display, 'openweather_home', { label: 'OpenWeather Home' });
    expect(apiFetch).toHaveBeenCalledWith(
      display,
      '/v1/integration-accounts/openweather_home',
      expect.objectContaining({ method: 'PATCH' }),
    );
  });

  it('puts account secret and requests sign-in', async () => {
    vi.mocked(apiFetch).mockResolvedValue(new Response('{}'));
    await putIntegrationAccountSecret(display, 'pexels', 'key');
    await requestIntegrationAccountSignIn(display, 'work');
    expect(apiFetch).toHaveBeenCalledTimes(2);
  });

  it('probes oauth on display', async () => {
    vi.mocked(apiJson).mockResolvedValue({
      configured: false,
      status: 'sign_in_required',
    });
    const res = await probeIntegrationAccountOAuth(display, 'work');
    expect(res.status).toBe('sign_in_required');
    expect(apiJson).toHaveBeenCalledWith(
      display,
      '/v1/integration-accounts/work/oauth-probe',
      expect.objectContaining({ method: 'POST' }),
    );
  });
});
