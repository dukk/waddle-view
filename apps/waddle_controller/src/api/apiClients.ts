import { apiFetch, apiJson } from '@/api/client';
import type { SavedDisplay } from '@/storage/displays';
import type { AdoptionConfirmResult } from '@/api/adoption';

export type ApiClientListItem = {
  id: string;
  identifier: string;
  role: string;
  masked_api_key: string;
  created_at_ms: number;
  updated_at_ms: number;
};

export type AdoptionSessionInfo = {
  identifier: string;
  role: string;
  permissions: string[];
};

export async function listApiClients(
  display: SavedDisplay,
): Promise<ApiClientListItem[]> {
  const body = await apiJson<{ items: ApiClientListItem[] }>(
    display,
    '/v1/adoption/clients',
  );
  return body.items ?? [];
}

export async function issueApiClient(
  display: SavedDisplay,
  input: { identifier: string; role: string },
): Promise<AdoptionConfirmResult> {
  return apiJson<AdoptionConfirmResult>(display, '/v1/adoption/clients', {
    method: 'POST',
    body: JSON.stringify({
      identifier: input.identifier.trim(),
      role: input.role,
    }),
  });
}

export async function revokeApiClient(display: SavedDisplay, clientId: string): Promise<void> {
  await apiFetch(
    display,
    `/v1/adoption/clients/${encodeURIComponent(clientId)}`,
    { method: 'DELETE' },
  );
}
