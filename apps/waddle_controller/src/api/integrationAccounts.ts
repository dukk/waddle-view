import { apiJson } from '@/api/client';
import type { SavedDisplay } from '@/storage/displays';
import type { IntegrationAccountsDetail } from '@/util/integrationAccountStatus';

export async function fetchIntegrationAccountsDetail(
  display: SavedDisplay,
  integrationId: string,
): Promise<IntegrationAccountsDetail> {
  return apiJson<IntegrationAccountsDetail>(
    display,
    `/v1/integrations/${encodeURIComponent(integrationId)}/accounts`,
  );
}
