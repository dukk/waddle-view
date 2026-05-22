export const LIST_LAYOUT_STORAGE_KEY = 'waddle_controller_list_layout_v1';

export const LIST_LAYOUT_PAGE_KEYS = [
  'programs',
  'screens',
  'ticker-tapes',
  'overlays',
  'integrations',
  'displays',
  'interests',
  'plugins',
  'data',
  'activity',
  'curators',
  'users',
  'display-ops-backups',
  'controller-backup-schedules',
] as const;

/** Pages that default to table layout when no preference is stored. */
const TABLE_DEFAULT_PAGES = new Set<ListLayoutPageKey>(['data', 'activity']);

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
  if (v === 'table') return 'table';
  if (v === 'card') return 'card';
  return TABLE_DEFAULT_PAGES.has(page) ? 'table' : 'card';
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
