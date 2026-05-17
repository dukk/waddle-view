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
    return parsed.filter(isDisplay).map((x) => toSavedDisplay(x as Record<string, unknown>));
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

export function addDisplay(input: {
  baseUrl: string;
  label?: string;
}): SavedDisplay {
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

/** Returns an existing display row when [baseUrl] already exists (normalized). */
export function upsertDisplayByBaseUrl(input: {
  baseUrl: string;
  label?: string;
}): SavedDisplay {
  const normalized = normalizeBaseUrl(input.baseUrl);
  const displays = loadDisplays();
  const hit = displays.find((d) => normalizeBaseUrl(d.baseUrl) === normalized);
  if (hit) {
    return hit;
  }
  return addDisplay(input);
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
  const next = parsed.filter(isDisplay).map((x) => toSavedDisplay(x as Record<string, unknown>));
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

function toSavedDisplay(o: Record<string, unknown>): SavedDisplay {
  return {
    id: String(o.id),
    label: String(o.label),
    baseUrl: normalizeBaseUrl(String(o.baseUrl)),
  };
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
      next.push(toSavedDisplay(o));
    }
  }
  saveDisplays(next);
}
