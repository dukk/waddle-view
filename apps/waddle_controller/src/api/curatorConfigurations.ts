import { apiFetch, apiJson } from '@/api/client';
import type { SavedDisplay } from '@/storage/displays';

export const CURATOR_LAYERS = ['exclusive', 'base', 'enhancement'] as const;
export type CuratorLayer = (typeof CURATOR_LAYERS)[number];

export type CuratorScheduleRule = {
  id: string;
  configuration_id: string;
  priority: number;
  state_predicate: string | null;
  days_of_week_mask: number | null;
  start_time_minutes: number | null;
  end_time_minutes: number | null;
  start_month: number | null;
  start_day: number | null;
  end_month: number | null;
  end_day: number | null;
  repeat_annually: boolean;
  year_exact: number | null;
  nth_week_of_month: number | null;
  nth_weekday: number | null;
};

export type CuratorConfigurationMembers = {
  screens: string[];
  tickers: string[];
  overlays: string[];
};

export type CuratorConfigurationSummary = {
  id: string;
  name: string;
  layer: CuratorLayer;
  sort_order: number;
  program_duration_seconds: number;
  history_depth: number;
  require_news_photo_for_screens: boolean;
  theme_id_override: string | null;
  default_config: boolean;
};

export type CuratorConfigurationDetail = CuratorConfigurationSummary & {
  rules: CuratorScheduleRule[];
  members: CuratorConfigurationMembers;
};

export type CuratorStatePredicateMeta = {
  id: string;
  label: string;
  description: string;
  implemented: boolean;
};

export type ActiveCuratorMatch = {
  configuration_id: string;
  configuration_name: string;
  layer: CuratorLayer;
  matched_rule_id: string;
  match_reason: string;
};

export type ActiveCuratorResponse = {
  exclusive: ActiveCuratorMatch | null;
  base: ActiveCuratorMatch | null;
  enhancements: ActiveCuratorMatch[];
};

export type CuratorConfigurationWriteBody = {
  name?: string;
  layer?: CuratorLayer;
  sort_order?: number;
  program_duration_seconds?: number;
  history_depth?: number;
  require_news_photo_for_screens?: boolean;
  theme_id_override?: string | null;
  default_config?: boolean;
  rules?: Omit<CuratorScheduleRule, 'configuration_id'>[];
  members?: CuratorConfigurationMembers;
};

export async function listCuratorConfigurations(
  display: SavedDisplay,
): Promise<CuratorConfigurationSummary[]> {
  const body = await apiJson<{ items: CuratorConfigurationSummary[] }>(
    display,
    '/v1/curator/configurations',
  );
  return body.items ?? [];
}

export async function fetchCuratorConfiguration(
  display: SavedDisplay,
  id: string,
): Promise<CuratorConfigurationDetail> {
  return apiJson<CuratorConfigurationDetail>(
    display,
    `/v1/curator/configurations/${encodeURIComponent(id)}`,
  );
}

export async function fetchActiveCurator(display: SavedDisplay): Promise<ActiveCuratorResponse> {
  return apiJson<ActiveCuratorResponse>(display, '/v1/curator/active');
}

export async function fetchCuratorStatePredicates(
  display: SavedDisplay,
): Promise<CuratorStatePredicateMeta[]> {
  const body = await apiJson<{ items: CuratorStatePredicateMeta[] }>(
    display,
    '/v1/meta/curator-state-predicates',
  );
  return body.items ?? [];
}

export async function createCuratorConfiguration(
  display: SavedDisplay,
  body: CuratorConfigurationWriteBody & { id: string },
): Promise<void> {
  await apiFetch(display, '/v1/curator/configurations', {
    method: 'POST',
    body: JSON.stringify(body),
  });
}

export async function updateCuratorConfiguration(
  display: SavedDisplay,
  id: string,
  body: CuratorConfigurationWriteBody,
): Promise<void> {
  await apiFetch(display, `/v1/curator/configurations/${encodeURIComponent(id)}`, {
    method: 'PATCH',
    body: JSON.stringify(body),
  });
}

export async function deleteCuratorConfiguration(display: SavedDisplay, id: string): Promise<void> {
  await apiFetch(display, `/v1/curator/configurations/${encodeURIComponent(id)}`, {
    method: 'DELETE',
  });
}
