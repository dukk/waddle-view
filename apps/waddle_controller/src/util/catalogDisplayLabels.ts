import { alertSeverityLabel, alertSourceLabel } from '@/constants/alertEnumLabels';
import { integrationDisplayName } from '@/util/integrationDisplayName';
import type { IcalFeedConfig } from '@/util/icalCalendarConfig';

export type CatalogCategory = { id: string; label: string };

export type IntegrationAccountLabel = { id: string; label: string };

export type AlertLifecycleStatus = 'active' | 'expired' | 'dismissed';

export function alertLifecycleStatus(
  row: Record<string, unknown>,
  nowMs = Date.now(),
): AlertLifecycleStatus {
  if (row.dismissed_at_ms != null && row.dismissed_at_ms !== '') {
    return 'dismissed';
  }
  const expires = row.expires_at_ms;
  if (typeof expires === 'number' && Number.isFinite(expires) && expires <= nowMs) {
    return 'expired';
  }
  return 'active';
}

export function alertLifecycleLabel(status: AlertLifecycleStatus): string {
  switch (status) {
    case 'active':
      return 'Active';
    case 'expired':
      return 'Expired';
    case 'dismissed':
      return 'Dismissed';
  }
}

export function categoryIdsForRow(row: Record<string, unknown>): string[] {
  const ids = row.category_ids;
  if (Array.isArray(ids)) {
    return ids.map((id) => String(id)).filter(Boolean);
  }
  const single = String(row.category_id ?? row.category ?? '').trim();
  return single ? [single] : [];
}

export function categoryLabelsForRow(
  row: Record<string, unknown>,
  categories: CatalogCategory[],
): string[] {
  return categoryIdsForRow(row).map((id) => {
    const hit = categories.find((c) => c.id === id);
    return hit?.label ?? id;
  });
}

export type CalendarSourceDetail = {
  integrationLabel: string;
  accountOrFeedLabel: string;
};

export function parseCalendarEventSource(
  source: string | null | undefined,
  ctx: {
    integrationAccounts: IntegrationAccountLabel[];
    icalFeedsById: Record<string, { label?: string; url: string }>;
  },
): CalendarSourceDetail {
  const raw = (source ?? '').trim();
  const integrationLabel = integrationDisplayName(
    raw.startsWith('google_calendar:')
      ? 'calendar_google'
      : raw.startsWith('outlook_calendar:')
        ? 'calendar_outlook'
        : raw.startsWith('ical_feed:')
          ? 'calendar_ical'
          : raw === 'manual_entry'
            ? 'manual_entry'
            : raw,
  );

  if (!raw || raw === 'manual_entry') {
    return { integrationLabel, accountOrFeedLabel: integrationDisplayName('manual_entry') };
  }

  if (raw.startsWith('google_calendar:')) {
    const accountId = raw.slice('google_calendar:'.length);
    return {
      integrationLabel,
      accountOrFeedLabel: resolveAccountLabel(accountId, ctx.integrationAccounts),
    };
  }

  if (raw.startsWith('outlook_calendar:')) {
    const accountId = raw.slice('outlook_calendar:'.length);
    return {
      integrationLabel,
      accountOrFeedLabel: resolveAccountLabel(accountId, ctx.integrationAccounts),
    };
  }

  if (raw.startsWith('ical_feed:')) {
    const feedId = raw.slice('ical_feed:'.length);
    const feed = ctx.icalFeedsById[feedId];
    if (feed) {
      return {
        integrationLabel,
        accountOrFeedLabel: feed.label?.trim() || feed.url || feedId,
      };
    }
    return { integrationLabel, accountOrFeedLabel: feedId };
  }

  return { integrationLabel, accountOrFeedLabel: raw };
}

function resolveAccountLabel(
  accountId: string,
  accounts: IntegrationAccountLabel[],
): string {
  const id = accountId.trim();
  if (!id) return '—';
  const hit = accounts.find((a) => a.id === id);
  return hit?.label?.trim() || id;
}

export function newsSourceLabel(
  row: Record<string, unknown>,
  feeds: { id: string; title: string | null; url: string }[],
): string {
  const integration = integrationDisplayName(
    typeof row.integration_type === 'string' ? row.integration_type : 'news_rss',
  );
  const feedId = String(row.feed_id ?? '').trim();
  if (!feedId) return integration;
  const feed = feeds.find((f) => f.id === feedId);
  const feedName = feed?.title?.trim() || feed?.url?.trim();
  return feedName ? `${integration} · ${feedName}` : integration;
}

export function icalFeedsByIdFromConfig(feeds: IcalFeedConfig[]): Record<
  string,
  { label?: string; url: string }
> {
  const out: Record<string, { label?: string; url: string }> = {};
  for (const f of feeds) {
    out[f.id] = { label: f.label, url: f.url };
  }
  return out;
}

export { alertSeverityLabel, alertSourceLabel };
