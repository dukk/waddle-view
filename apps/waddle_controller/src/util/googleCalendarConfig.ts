import type { IntegrationAccountRow } from '@/util/integrationAccounts';

export type GoogleCalendarSelection = {
  id: string;
  name: string;
  categoryIds: string[];
  selected: boolean;
};

export type GoogleCalendarConfigState = {
  googleAccountKey: string;
  pastDays: number;
  futureDays: number;
  calendars: GoogleCalendarSelection[];
};

const kDefaultPastFutureDays = 30;

function positiveInt(value: unknown, fallback: number): number {
  if (typeof value === 'number' && Number.isFinite(value) && value > 0) {
    return Math.floor(value);
  }
  return fallback;
}

function categoryIdsFromRaw(raw: unknown): string[] {
  if (Array.isArray(raw)) {
    const out: string[] = [];
    for (const e of raw) {
      if (typeof e === 'string') {
        const t = e.trim();
        if (t && !out.includes(t)) out.push(t);
      }
    }
    return out;
  }
  if (typeof raw === 'string') {
    const t = raw.trim();
    return t ? [t] : [];
  }
  return [];
}

function calendarEntryFromRaw(raw: unknown): GoogleCalendarSelection | null {
  if (typeof raw === 'string') {
    const name = raw.trim();
    if (!name) return null;
    return { id: name, name, categoryIds: [], selected: true };
  }
  if (raw && typeof raw === 'object' && !Array.isArray(raw)) {
    const m = raw as Record<string, unknown>;
    const id = String(m.id ?? m.calendar ?? m.name ?? '').trim();
    if (!id) return null;
    const name = String(m.name ?? m.calendar ?? id).trim() || id;
    const categoryIds = [
      ...categoryIdsFromRaw(m.categoryIds),
      ...categoryIdsFromRaw(m.categoryId ?? m.category),
    ];
    const seen = new Set<string>();
    const deduped = categoryIds.filter((c) => {
      if (seen.has(c)) return false;
      seen.add(c);
      return true;
    });
    return { id, name, categoryIds: deduped, selected: true };
  }
  return null;
}

/** Reads Google Calendar integration config_json into UI state. */
export function parseGoogleCalendarConfig(
  raw: Record<string, unknown>,
): GoogleCalendarConfigState {
  const pastDays = positiveInt(raw.pastDays, kDefaultPastFutureDays);
  const futureDays = positiveInt(raw.futureDays, kDefaultPastFutureDays);
  const accounts = raw.accounts;
  if (!Array.isArray(accounts) || accounts.length === 0) {
    return { googleAccountKey: '', pastDays, futureDays, calendars: [] };
  }
  const first = accounts[0];
  if (!first || typeof first !== 'object' || Array.isArray(first)) {
    return { googleAccountKey: '', pastDays, futureDays, calendars: [] };
  }
  const account = first as Record<string, unknown>;
  const googleAccountKey = String(account.googleAccountKey ?? '').trim();
  const sources = account.sources;
  const calendars: GoogleCalendarSelection[] = [];
  if (Array.isArray(sources) && sources.length > 0) {
    const source = sources[0];
    if (source && typeof source === 'object' && !Array.isArray(source)) {
      const src = source as Record<string, unknown>;
      const rawCalendars = src.calendars;
      if (Array.isArray(rawCalendars)) {
        for (const entry of rawCalendars) {
          const parsed = calendarEntryFromRaw(entry);
          if (parsed) calendars.push(parsed);
        }
      }
    }
  }
  return { googleAccountKey, pastDays, futureDays, calendars };
}

/** Builds config_json for PATCH from UI state (selected calendars only). */
export function buildGoogleCalendarConfigJson(
  state: GoogleCalendarConfigState,
): Record<string, unknown> {
  const selected = state.calendars.filter((c) => c.selected);
  const accounts =
    state.googleAccountKey.trim().length > 0
      ? [
          {
            googleAccountKey: state.googleAccountKey.trim(),
            sources: [
              {
                calendars: selected.map((c) => ({
                  calendar: c.id,
                  ...(c.categoryIds.length > 0
                    ? { categoryIds: c.categoryIds }
                    : {}),
                })),
              },
            ],
          },
        ]
      : [];
  return {
    accounts,
    pastDays: state.pastDays,
    futureDays: state.futureDays,
  };
}

/** Merges remote calendar list with saved selections. */
export function mergeGoogleCalendarsWithSaved(
  remote: { id: string; name: string }[],
  saved: GoogleCalendarSelection[],
): GoogleCalendarSelection[] {
  const savedById = new Map(saved.map((c) => [c.id, c]));
  const savedByName = new Map(saved.map((c) => [c.name.toLowerCase(), c]));
  return remote.map((c) => {
    const prior = savedById.get(c.id) ?? savedByName.get(c.name.toLowerCase());
    return {
      id: c.id,
      name: c.name,
      categoryIds: prior?.categoryIds ?? [],
      selected: prior?.selected ?? false,
    };
  });
}

export function googleCalendarConfigReady(
  state: GoogleCalendarConfigState,
  googleAccounts: IntegrationAccountRow[],
): boolean {
  if (!state.googleAccountKey) return false;
  const account = googleAccounts.find((a) => a.id === state.googleAccountKey);
  if (!account?.configured) return false;
  return state.calendars.some((c) => c.selected);
}
