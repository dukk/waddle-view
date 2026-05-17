export type DisplayTimezoneOption = { id: string; label: string };

/** Fallback when `Intl.supportedValuesOf('timeZone')` is unavailable (tests / legacy runtimes). */
const DISPLAY_TIMEZONE_FALLBACK: DisplayTimezoneOption[] = [
  { id: 'America/New_York', label: 'America/New_York' },
  { id: 'America/Chicago', label: 'America/Chicago' },
  { id: 'America/Denver', label: 'America/Denver' },
  { id: 'America/Los_Angeles', label: 'America/Los_Angeles' },
  { id: 'UTC', label: 'UTC' },
  { id: 'Europe/London', label: 'Europe/London' },
];

let cachedAllOptions: DisplayTimezoneOption[] | null = null;

function ianaTimezoneIds(): string[] {
  if (typeof Intl !== 'undefined' && 'supportedValuesOf' in Intl) {
    return Intl.supportedValuesOf('timeZone').slice().sort((a, b) => a.localeCompare(b));
  }
  return DISPLAY_TIMEZONE_FALLBACK.map((o) => o.id);
}

/** Wall-clock offset hint for the picker (DST-aware at load time). */
export function formatDisplayTimezoneLabel(id: string): string {
  try {
    const parts = new Intl.DateTimeFormat('en-US', {
      timeZone: id,
      timeZoneName: 'shortOffset',
    }).formatToParts(new Date());
    const offset = parts.find((p) => p.type === 'timeZoneName')?.value;
    return offset ? `${id} (${offset})` : id;
  } catch {
    return id;
  }
}

/** All IANA ids supported by the host ICU build (matches typical display `display.timezone` values). */
export function getAllDisplayTimezoneOptions(): DisplayTimezoneOption[] {
  if (!cachedAllOptions) {
    cachedAllOptions = ianaTimezoneIds().map((id) => ({
      id,
      label: formatDisplayTimezoneLabel(id),
    }));
  }
  return cachedAllOptions;
}

/** @deprecated Use {@link getAllDisplayTimezoneOptions}; kept for tests and imports. */
export const DISPLAY_TIMEZONE_OPTIONS = getAllDisplayTimezoneOptions();

/** Full list plus the current value when it is not a known IANA id (legacy / alias). */
export function displayTimezoneSelectOptions(currentId: string): DisplayTimezoneOption[] {
  const trimmed = currentId.trim();
  const base = getAllDisplayTimezoneOptions();
  if (trimmed && !base.some((o) => o.id === trimmed)) {
    return [{ id: trimmed, label: `${trimmed} (custom)` }, ...base];
  }
  return base;
}

/** Case-insensitive filter on IANA id and label (for Autocomplete `filterOptions`). */
export function filterDisplayTimezoneOptions(
  options: DisplayTimezoneOption[],
  query: string,
): DisplayTimezoneOption[] {
  const q = query.trim().toLowerCase();
  if (!q) return options;
  return options.filter(
    (o) => o.id.toLowerCase().includes(q) || o.label.toLowerCase().includes(q),
  );
}
