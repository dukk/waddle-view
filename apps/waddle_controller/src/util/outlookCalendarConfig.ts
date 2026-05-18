export type OutlookCalendarSelection = {
  id: string;
  name: string;
  categoryId: string;
  selected: boolean;
};

export type OutlookCalendarConfigState = {
  graphAccountKey: string;
  pastDays: number;
  futureDays: number;
  calendars: OutlookCalendarSelection[];
};

function positiveInt(value: unknown, fallback: number): number {
  if (typeof value === 'number' && Number.isFinite(value) && value > 0) {
    return Math.floor(value);
  }
  return fallback;
}

function calendarEntryFromRaw(raw: unknown): OutlookCalendarSelection | null {
  if (typeof raw === 'string') {
    const name = raw.trim();
    if (!name) return null;
    return { id: name, name, categoryId: '', selected: true };
  }
  if (raw && typeof raw === 'object' && !Array.isArray(raw)) {
    const m = raw as Record<string, unknown>;
    const id = String(m.id ?? m.calendar ?? m.name ?? '').trim();
    if (!id) return null;
    const name = String(m.name ?? m.calendar ?? id).trim() || id;
    const categoryId = String(m.categoryId ?? m.category ?? '').trim();
    return { id, name, categoryId, selected: true };
  }
  return null;
}

/** Reads Outlook calendar integration config_json into UI state. */
export function parseOutlookCalendarConfig(
  raw: Record<string, unknown>,
): OutlookCalendarConfigState {
  const pastDays = positiveInt(raw.pastDays, 14);
  const futureDays = positiveInt(raw.futureDays, 14);
  const accounts = raw.accounts;
  if (!Array.isArray(accounts) || accounts.length === 0) {
    return { graphAccountKey: '', pastDays, futureDays, calendars: [] };
  }
  const first = accounts[0];
  if (!first || typeof first !== 'object' || Array.isArray(first)) {
    return { graphAccountKey: '', pastDays, futureDays, calendars: [] };
  }
  const account = first as Record<string, unknown>;
  const graphAccountKey = String(account.graphAccountKey ?? '').trim();
  const sources = account.sources;
  const calendars: OutlookCalendarSelection[] = [];
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
  return { graphAccountKey, pastDays, futureDays, calendars };
}

/** Builds config_json for PATCH from UI state (selected calendars only). */
export function buildOutlookCalendarConfigJson(
  state: OutlookCalendarConfigState,
): Record<string, unknown> {
  const selected = state.calendars.filter((c) => c.selected);
  const accounts =
    state.graphAccountKey.trim().length > 0
      ? [
          {
            graphAccountKey: state.graphAccountKey.trim(),
            sources: [
              {
                mailbox: 'me',
                calendars: selected.map((c) => ({
                  id: c.id,
                  name: c.name,
                  category: c.categoryId.trim() || undefined,
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

/** Merges Graph calendar list with saved selections. */
export function mergeOutlookCalendarsWithSaved(
  remote: { id: string; name: string }[],
  saved: OutlookCalendarSelection[],
): OutlookCalendarSelection[] {
  const savedById = new Map(saved.map((c) => [c.id, c]));
  const savedByName = new Map(saved.map((c) => [c.name.toLowerCase(), c]));
  return remote.map((c) => {
    const prior = savedById.get(c.id) ?? savedByName.get(c.name.toLowerCase());
    return {
      id: c.id,
      name: c.name,
      categoryId: prior?.categoryId ?? '',
      selected: prior?.selected ?? false,
    };
  });
}
