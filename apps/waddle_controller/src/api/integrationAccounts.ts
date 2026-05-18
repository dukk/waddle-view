import { apiFetch, apiJson } from '@/api/client';
import type { SavedDisplay } from '@/storage/displays';
import type { IntegrationAccountsDetail } from '@/util/integrationAccountStatus';
import type { IntegrationAccountsResponse } from '@/util/integrationAccounts';

export async function fetchIntegrationAccounts(
  display: SavedDisplay,
): Promise<IntegrationAccountsResponse> {
  return apiJson<IntegrationAccountsResponse>(display, '/v1/integration-accounts');
}

export async function patchIntegrationAccount(
  display: SavedDisplay,
  accountId: string,
  body: { label: string },
): Promise<void> {
  await apiFetch(display, `/v1/integration-accounts/${encodeURIComponent(accountId)}`, {
    method: 'PATCH',
    body: JSON.stringify(body),
  });
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

/** Starts OAuth on the display (device-code alert) and fetches profile when already signed in. */
export async function probeIntegrationAccountOAuth(
  display: SavedDisplay,
  accountId: string,
): Promise<{
  configured: boolean;
  status?: string;
  sign_in_alert_active?: boolean;
  profile?: Record<string, unknown>;
}> {
  return apiJson(display, `/v1/integration-accounts/${encodeURIComponent(accountId)}/oauth-probe`, {
    method: 'POST',
  });
}

export type DeleteIntegrationAccountResult = {
  disabled_integration_ids: string[];
};

export async function deleteIntegrationAccount(
  display: SavedDisplay,
  accountId: string,
  options?: { confirm?: boolean },
): Promise<DeleteIntegrationAccountResult> {
  const confirm = options?.confirm === true;
  const query = confirm ? '?confirm=true' : '';
  return apiJson<DeleteIntegrationAccountResult>(
    display,
    `/v1/integration-accounts/${encodeURIComponent(accountId)}${query}`,
    { method: 'DELETE' },
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
