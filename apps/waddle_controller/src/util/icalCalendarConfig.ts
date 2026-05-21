export type IcalFeedConfig = {
  id: string;
  url: string;
  label?: string;
  categoryId: string;
};

export type IcalCalendarConfigState = {
  feeds: IcalFeedConfig[];
};

const kSyncWindowDays = 30;

export function newIcalFeedId(): string {
  return crypto.randomUUID();
}

export function parseIcalCalendarConfig(
  raw: Record<string, unknown>,
): IcalCalendarConfigState {
  const feedsRaw = raw.feeds;
  const feeds: IcalFeedConfig[] = [];
  if (Array.isArray(feedsRaw)) {
    for (const f of feedsRaw) {
      if (!f || typeof f !== 'object') continue;
      const row = f as Record<string, unknown>;
      const url = typeof row.url === 'string' ? row.url.trim() : '';
      if (!url) continue;
      const idRaw = row.id;
      const id =
        typeof idRaw === 'string' && idRaw.trim() !== '' ? idRaw.trim() : newIcalFeedId();
      const labelRaw = row.label;
      const label =
        typeof labelRaw === 'string' && labelRaw.trim() !== '' ? labelRaw.trim() : undefined;
      const categoryId = parseCategoryId(row);
      feeds.push({ id, url, label, categoryId });
    }
  }
  return { feeds };
}

export function buildIcalCalendarConfigJson(
  state: IcalCalendarConfigState,
): Record<string, unknown> {
  return {
    pastDays: kSyncWindowDays,
    futureDays: kSyncWindowDays,
    feeds: state.feeds.map((f) => {
      const entry: Record<string, unknown> = {
        id: f.id,
        url: f.url,
        categoryId: f.categoryId,
        enabled: true,
      };
      if (f.label) {
        entry.label = f.label;
      }
      return entry;
    }),
  };
}

export function icalConfigReady(state: IcalCalendarConfigState): boolean {
  if (state.feeds.length === 0) return false;
  return state.feeds.every((f) => f.url.trim() !== '' && f.categoryId.trim() !== '');
}

export function feedKey(f: IcalFeedConfig): string {
  return f.id;
}

export function mergeFeedIntoList(
  feeds: IcalFeedConfig[],
  next: IcalFeedConfig,
): IcalFeedConfig[] {
  const key = feedKey(next);
  const without = feeds.filter((f) => feedKey(f) !== key);
  return [...without, next];
}

/** Basic http(s) or webcal URL check for operator input. */
export function isValidIcalFeedUrl(url: string): boolean {
  const trimmed = url.trim();
  if (!trimmed) return false;
  try {
    const normalized = trimmed.replace(/^webcal:\/\//i, 'https://');
    const parsed = new URL(normalized);
    return parsed.protocol === 'http:' || parsed.protocol === 'https:';
  } catch {
    return false;
  }
}

function parseCategoryId(row: Record<string, unknown>): string {
  const single = row.categoryId ?? row.category;
  if (typeof single === 'string' && single.trim() !== '') {
    return single.trim();
  }
  const multi = row.categoryIds ?? row.category_ids;
  if (Array.isArray(multi)) {
    for (const c of multi) {
      if (typeof c === 'string' && c.trim() !== '') {
        return c.trim();
      }
    }
  }
  return '';
}
