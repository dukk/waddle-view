import { apiFetch, apiJson } from '@/api/client';
import type { SavedDisplay } from '@/storage/displays';

export type OAuthProviderStatus = {
  id: string;
  label: string;
  account_type: string;
  client_id_configured: boolean;
};

export async function listOAuthProviders(
  display: SavedDisplay,
): Promise<OAuthProviderStatus[]> {
  const body = await apiJson<{ items: OAuthProviderStatus[] }>(
    display,
    '/v1/oauth-providers',
  );
  return body.items ?? [];
}

export async function putOAuthProviderClientId(
  display: SavedDisplay,
  providerId: string,
  value: string,
): Promise<void> {
  await apiFetch(display, `/v1/oauth-providers/${encodeURIComponent(providerId)}/client-id`, {
    method: 'PUT',
    body: JSON.stringify({ value }),
  });
}
