export const LIST_LAYOUT_STORAGE_KEY = 'waddle_controller_list_layout_v1';

export const LIST_LAYOUT_PAGE_KEYS = [
  'programs',
  'screens',
  'ticker-tapes',
  'overlays',
  'integrations',
  'displays',
] as const;

export type ListLayoutPageKey = (typeof LIST_LAYOUT_PAGE_KEYS)[number];

export type ListLayoutMode = 'card' | 'table';

type StoredLayouts = Partial<Record<ListLayoutPageKey, ListLayoutMode>>;

function readAll(): StoredLayouts {
  try {
    const raw = localStorage.getItem(LIST_LAYOUT_STORAGE_KEY);
    if (!raw) return {};
    const parsed: unknown = JSON.parse(raw);
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) return {};
    return parsed as StoredLayouts;
  } catch {
    return {};
  }
}

export function readListLayoutPreference(page: ListLayoutPageKey): ListLayoutMode {
  const v = readAll()[page];
  return v === 'table' ? 'table' : 'card';
}

export function writeListLayoutPreference(page: ListLayoutPageKey, value: ListLayoutMode): void {
  try {
    const all = readAll();
    all[page] = value;
    localStorage.setItem(LIST_LAYOUT_STORAGE_KEY, JSON.stringify(all));
  } catch {
    /* ignore */
  }
}
