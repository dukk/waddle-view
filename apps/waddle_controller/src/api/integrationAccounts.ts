import { apiFetch, apiJson } from '@/api/client';
import type { SavedDisplay } from '@/storage/displays';
import type { IntegrationAccountsDetail } from '@/util/integrationAccountStatus';
import type { IntegrationAccountsResponse } from '@/util/integrationAccounts';

export async function fetchIntegrationAccounts(
  display: SavedDisplay,
): Promise<IntegrationAccountsResponse> {
  return apiJson<IntegrationAccountsResponse>(display, '/v1/integration-accounts');
}

export async function createIntegrationAccount(
  display: SavedDisplay,
  body: {
    account_type: string;
    account_key?: string;
    label?: string;
  },
): Promise<{ account_id: string }> {
  return apiJson<{ account_id: string }>(display, '/v1/integration-accounts', {
    method: 'POST',
    body: JSON.stringify(body),
  });
}

export async function putIntegrationAccountSecret(
  display: SavedDisplay,
  accountId: string,
  value: string,
): Promise<void> {
  await apiFetch(
    display,
    `/v1/integration-accounts/${encodeURIComponent(accountId)}/secrets/access_token`,
    {
      method: 'PUT',
      body: JSON.stringify({ value }),
    },
  );
}

export async function requestIntegrationAccountSignIn(
  display: SavedDisplay,
  accountId: string,
): Promise<void> {
  await apiFetch(
    display,
    `/v1/integration-accounts/${encodeURIComponent(accountId)}/request-sign-in`,
    { method: 'POST' },
  );
}

export async function fetchIntegrationAccountsDetail(
  display: SavedDisplay,
  integrationId: string,
): Promise<IntegrationAccountsDetail> {
  return apiJson<IntegrationAccountsDetail>(
    display,
    `/v1/integrations/${encodeURIComponent(integrationId)}/accounts`,
  );
}
