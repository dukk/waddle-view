const STORAGE_KEY = 'waddle_controller_displays_v1';
const LOCAL_DISPLAYS_MIGRATED_KEY = 'waddle_controller_displays_server_migrated';

export const DISPLAYS_CHANGED_EVENT = 'waddle_controller_displays_changed';

export function notifyDisplaysChanged(): void {
  if (typeof window !== 'undefined') {
    window.dispatchEvent(new Event(DISPLAYS_CHANGED_EVENT));
  }
}

export type SavedDisplay = {
  id: string;
  label: string;
  baseUrl: string;
  /** Adopted display REST bearer token (included in backup export). */
  apiKey?: string;
  /** Adopted role on the display (`admin`, `operator`, …). */
  role?: string;
  /** Adoption identifier label shown in the UI. */
  identifier?: string;
};

function randomId(): string {
  return `d_${Math.random().toString(36).slice(2, 12)}`;
}

function readDisplaysRaw(): SavedDisplay[] {
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

export function loadDisplays(): SavedDisplay[] {
  return mergeLegacySessionsIntoDisplays(readDisplaysRaw());
}

export function saveDisplays(displays: SavedDisplay[]): void {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(displays));
  notifyDisplaysChanged();
}

export function clearDisplaysStorage(): void {
  localStorage.removeItem(STORAGE_KEY);
  notifyDisplaysChanged();
}

/** True when this browser has a saved display list in localStorage. */
export function hasStoredDisplaysInBrowser(): boolean {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return false;
    const parsed = JSON.parse(raw) as unknown;
    return Array.isArray(parsed) && parsed.length > 0;
  } catch {
    return false;
  }
}

export function isLocalDisplaysMigrationComplete(): boolean {
  return localStorage.getItem(LOCAL_DISPLAYS_MIGRATED_KEY) === '1';
}

export function setLocalDisplaysMigrationComplete(): void {
  localStorage.setItem(LOCAL_DISPLAYS_MIGRATED_KEY, '1');
}

export function clearLocalDisplaysMigrationComplete(): void {
  localStorage.removeItem(LOCAL_DISPLAYS_MIGRATED_KEY);
}

/** Local display rows exist and have not been migrated to the controller server yet. */
export function shouldOfferLocalDisplaysMigration(): boolean {
  return hasStoredDisplaysInBrowser() && !isLocalDisplaysMigrationComplete();
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

/** Updates the menu label for a saved display. Returns null when [id] is missing or [label] is blank. */
export function updateDisplayLabel(id: string, label: string): SavedDisplay | null {
  return updateDisplaySettings(id, { label });
}

function parseDisplayBaseUrl(baseUrl: string): string | null {
  const normalized = normalizeBaseUrl(baseUrl);
  if (!normalized) {
    return null;
  }
  try {
    void new URL(normalized);
    return normalized;
  } catch {
    return null;
  }
}

/** Updates label and/or base URL for a saved display. Returns null when validation fails. */
export function updateDisplaySettings(
  id: string,
  input: { label?: string; baseUrl?: string },
): SavedDisplay | null {
  const displays = readDisplaysRaw();
  const index = displays.findIndex((d) => d.id === id);
  if (index < 0) {
    return null;
  }
  const row = displays[index]!;
  const label =
    input.label !== undefined ? input.label.trim() : row.label;
  if (!label) {
    return null;
  }
  const baseUrl =
    input.baseUrl !== undefined ? parseDisplayBaseUrl(input.baseUrl) : row.baseUrl;
  if (input.baseUrl !== undefined && baseUrl === null) {
    return null;
  }
  const updated: SavedDisplay = { ...row, label, baseUrl: baseUrl ?? row.baseUrl };
  displays[index] = updated;
  saveDisplays(displays);
  return updated;
}

export function applyDisplayAdoption(
  displayId: string,
  adoption: { apiKey: string; role: string; identifier: string },
): void {
  const displays = readDisplaysRaw();
  const index = displays.findIndex((d) => d.id === displayId);
  if (index < 0) return;
  displays[index] = {
    ...displays[index]!,
    apiKey: adoption.apiKey,
    role: adoption.role,
    identifier: adoption.identifier,
  };
  saveDisplays(displays);
}

export function clearDisplayAdoption(displayId: string): void {
  const displays = readDisplaysRaw();
  const index = displays.findIndex((d) => d.id === displayId);
  if (index < 0) return;
  const row = displays[index]!;
  displays[index] = { id: row.id, label: row.label, baseUrl: row.baseUrl };
  saveDisplays(displays);
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
    typeof o.baseUrl === 'string'
  );
}

function toSavedDisplay(o: Record<string, unknown>): SavedDisplay {
  const row: SavedDisplay = {
    id: String(o.id),
    label: String(o.label),
    baseUrl: normalizeBaseUrl(String(o.baseUrl)),
  };
  if (typeof o.apiKey === 'string' && o.apiKey.length > 0) {
    row.apiKey = o.apiKey;
  }
  if (typeof o.role === 'string' && o.role.length > 0) {
    row.role = o.role;
  }
  if (typeof o.identifier === 'string' && o.identifier.length > 0) {
    row.identifier = o.identifier;
  }
  return row;
}

/** Lenient import for older backup shapes (same fields as [importDisplaysJson]). */
export function importDisplaysJsonLegacy(json: string): void {
  importDisplaysJson(json);
}

const LEGACY_SESSION_PREFIX = 'waddle_controller_session_v1:';

function mergeLegacySessionsIntoDisplays(displays: SavedDisplay[]): SavedDisplay[] {
  let changed = false;
  const next = displays.map((display) => {
    const legacy = readLegacySessionBlob(display.id);
    if (!legacy) return display;
    if (display.apiKey) {
      removeLegacySessionKey(display.id);
      return display;
    }
    changed = true;
    removeLegacySessionKey(display.id);
    return {
      ...display,
      apiKey: legacy.apiKey,
      role: legacy.role,
      identifier: legacy.identifier,
    };
  });
  if (changed) {
    saveDisplays(next);
    return next;
  }
  return displays;
}

function readLegacySessionBlob(
  displayId: string,
): { apiKey: string; role: string; identifier: string } | null {
  try {
    const raw =
      localStorage.getItem(`${LEGACY_SESSION_PREFIX}${displayId}`) ??
      sessionStorage.getItem(`${LEGACY_SESSION_PREFIX}${displayId}`);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as {
      apiKey?: string;
      role?: string;
      identifier?: string;
      expiresAtMs?: number;
    };
    if (
      typeof parsed.expiresAtMs === 'number' &&
      parsed.expiresAtMs <= Date.now()
    ) {
      removeLegacySessionKey(displayId);
      return null;
    }
    if (typeof parsed.apiKey !== 'string' || !parsed.apiKey) return null;
    if (typeof parsed.role !== 'string' || !parsed.role) return null;
    return {
      apiKey: parsed.apiKey,
      role: parsed.role,
      identifier:
        typeof parsed.identifier === 'string' ? parsed.identifier : '',
    };
  } catch {
    return null;
  }
}

function removeLegacySessionKey(displayId: string): void {
  localStorage.removeItem(`${LEGACY_SESSION_PREFIX}${displayId}`);
  sessionStorage.removeItem(`${LEGACY_SESSION_PREFIX}${displayId}`);
}

export function removeLegacySessionKeyForDisplay(displayId: string): void {
  removeLegacySessionKey(displayId);
}
