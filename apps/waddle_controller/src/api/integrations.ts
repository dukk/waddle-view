import { apiJson } from '@/api/client';
import type { SavedDisplay } from '@/storage/displays';
import type { IntegrationRequiredAccountType } from '@/util/integrationAccounts';
import type { IntegrationLinkedAccount } from '@/util/integrationAccountStatus';

export type IntegrationRow = {
  id: string;
  integration_type: string;
  integration_type_label?: string;
  enabled: boolean;
  poll_seconds: number;
  config_json: unknown;
  config_json_schema?: unknown;
  secrets_configured?: boolean;
  accounts_configured?: boolean;
  required_account_types?: IntegrationRequiredAccountType[];
  linked_accounts?: IntegrationLinkedAccount[];
};

export type IntegrationsListResponse = {
  items: IntegrationRow[];
  total: number;
  limit: number;
  offset: number;
  facets?: {
    family?: Record<string, number>;
  };
};

export type IntegrationsSortField =
  | 'id'
  | 'integration_type'
  | 'integration_type_label'
  | 'poll_seconds'
  | 'enabled';

export type IntegrationsListParams = {
  enabled?: boolean;
  limit: number;
  offset: number;
  sort?: IntegrationsSortField;
  order?: 'asc' | 'desc';
  family?: string | null;
  integration_type?: string | null;
  q?: string | null;
  secrets_configured?: boolean;
  accounts_configured?: boolean;
  facets?: 'family';
};

export function buildIntegrationsQuery(params: IntegrationsListParams): string {
  const p = new URLSearchParams();
  if (params.enabled !== undefined) {
    p.set('enabled', params.enabled ? 'true' : 'false');
  }
  p.set('limit', String(params.limit));
  p.set('offset', String(params.offset));
  if (params.sort) p.set('sort', params.sort);
  if (params.order) p.set('order', params.order);
  if (params.family) p.set('family', params.family);
  if (params.integration_type) p.set('integration_type', params.integration_type);
  const q = params.q?.trim();
  if (q) p.set('q', q);
  if (params.secrets_configured === true) p.set('secrets_configured', 'true');
  if (params.secrets_configured === false) p.set('secrets_configured', 'false');
  if (params.accounts_configured === true) p.set('accounts_configured', 'true');
  if (params.accounts_configured === false) p.set('accounts_configured', 'false');
  if (params.facets === 'family') p.set('facets', 'family');
  const s = p.toString();
  return s ? `?${s}` : '';
}

export async function listIntegrations(
  display: SavedDisplay,
  params: IntegrationsListParams,
  init?: RequestInit,
): Promise<IntegrationsListResponse> {
  const path = `/v1/integrations${buildIntegrationsQuery(params)}`;
  return apiJson<IntegrationsListResponse>(display, path, {
    cache: 'no-store',
    ...init,
  });
}
