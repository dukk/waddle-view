const STORAGE_KEY = 'waddle_controller_displays_v1';

export type SavedDisplay = {
  id: string;
  label: string;
  baseUrl: string;
};

function randomId(): string {
  return `d_${Math.random().toString(36).slice(2, 12)}`;
}

export function loadDisplays(): SavedDisplay[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as unknown;
    if (!Array.isArray(parsed)) return [];
    return parsed.filter(isDisplay);
  } catch {
    return [];
  }
}

export function saveDisplays(displays: SavedDisplay[]): void {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(displays));
}

export function normalizeBaseUrl(url: string): string {
  return url.trim().replace(/\/+$/, '');
}

export function addDisplay(input: { baseUrl: string; label?: string }): SavedDisplay {
  const displays = loadDisplays();
  const d: SavedDisplay = {
    id: randomId(),
    label: input.label?.trim() || normalizeBaseUrl(input.baseUrl),
    baseUrl: normalizeBaseUrl(input.baseUrl),
  };
  displays.push(d);
  saveDisplays(displays);
  return d;
}

export function removeDisplay(id: string): void {
  saveDisplays(loadDisplays().filter((d) => d.id !== id));
}

export function exportDisplaysJson(): string {
  return JSON.stringify(loadDisplays(), null, 2);
}

export function importDisplaysJson(json: string): void {
  const parsed = JSON.parse(json) as unknown;
  if (!Array.isArray(parsed)) throw new Error('Expected array');
  const next = parsed.filter(isDisplay);
  saveDisplays(next);
}

function isDisplay(x: unknown): x is SavedDisplay {
  if (!x || typeof x !== 'object') return false;
  const o = x as Record<string, unknown>;
  return (
    typeof o.id === 'string' &&
    typeof o.label === 'string' &&
    typeof o.baseUrl === 'string' &&
    !('apiKey' in o)
  );
}

/** Legacy import: strips apiKey from older backups. */
export function importDisplaysJsonLegacy(json: string): void {
  const parsed = JSON.parse(json) as unknown;
  if (!Array.isArray(parsed)) throw new Error('Expected array');
  const next: SavedDisplay[] = [];
  for (const item of parsed) {
    if (!item || typeof item !== 'object') continue;
    const o = item as Record<string, unknown>;
    if (
      typeof o.id === 'string' &&
      typeof o.label === 'string' &&
      typeof o.baseUrl === 'string'
    ) {
      next.push({
        id: o.id,
        label: o.label,
        baseUrl: normalizeBaseUrl(String(o.baseUrl)),
      });
    }
  }
  saveDisplays(next);
}
