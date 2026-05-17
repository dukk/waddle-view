import { isDisplayProxyAuthEnabled } from '@/api/displayAuthMode';
import { permissionsForRole } from '@/auth/rolePermissions';
import {
  applyDisplayAdoption,
  clearDisplayAdoption,
  loadDisplays,
  removeLegacySessionKeyForDisplay,
  type SavedDisplay,
} from '@/storage/displays';

const SESSION_PREFIX = 'waddle_controller_session_v1:';
const LEGACY_SESSION_PREFIX = SESSION_PREFIX;

export type DisplaySession = {
  apiKey: string;
  identifier: string;
  role: string;
  permissions: string[];
  /** Client-side hint only; display does not expire API keys today. */
  expiresAtMs: number;
};

function storageKey(displayId: string): string {
  return `${SESSION_PREFIX}${displayId}`;
}

function migrateSessionFromSessionStorage(displayId: string): DisplaySession | null {
  try {
    const raw = sessionStorage.getItem(`${LEGACY_SESSION_PREFIX}${displayId}`);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as DisplaySession;
    if (!parsed.apiKey || parsed.expiresAtMs <= Date.now()) {
      sessionStorage.removeItem(`${LEGACY_SESSION_PREFIX}${displayId}`);
      return null;
    }
    localStorage.setItem(storageKey(displayId), raw);
    sessionStorage.removeItem(`${LEGACY_SESSION_PREFIX}${displayId}`);
    return parsed;
  } catch {
    return null;
  }
}

function readLegacySession(displayId: string): DisplaySession | null {
  try {
    const raw = localStorage.getItem(storageKey(displayId));
    if (!raw) {
      const migrated = migrateSessionFromSessionStorage(displayId);
      if (migrated) return migrated;
      return null;
    }
    const parsed = JSON.parse(raw) as DisplaySession;
    if (!parsed.apiKey && !isDisplayProxyAuthEnabled()) {
      clearLegacySession(displayId);
      return null;
    }
    if (parsed.expiresAtMs <= Date.now()) {
      clearLegacySession(displayId);
      return null;
    }
    return parsed;
  } catch {
    return null;
  }
}

function clearLegacySession(displayId: string): void {
  localStorage.removeItem(storageKey(displayId));
  sessionStorage.removeItem(`${LEGACY_SESSION_PREFIX}${displayId}`);
}

function sessionFromDisplay(display: SavedDisplay): DisplaySession | null {
  const apiKey = display.apiKey ?? '';
  if (!apiKey && !isDisplayProxyAuthEnabled()) {
    return null;
  }
  const role = display.role;
  if (!role) {
    return null;
  }
  const identifier = display.identifier ?? '';
  return {
    apiKey,
    identifier,
    role,
    permissions: permissionsForRole(role),
    expiresAtMs: Date.now() + 365 * 24 * 60 * 60 * 1000,
  };
}

export function loadSession(displayId: string): DisplaySession | null {
  const display = loadDisplays().find((d) => d.id === displayId);
  if (display) {
    const fromDisplay = sessionFromDisplay(display);
    if (fromDisplay) {
      return fromDisplay;
    }
  }
  return readLegacySession(displayId);
}

export function saveSession(displayId: string, session: DisplaySession): void {
  const displays = loadDisplays();
  if (displays.some((d) => d.id === displayId)) {
    applyDisplayAdoption(displayId, {
      apiKey: session.apiKey,
      role: session.role,
      identifier: session.identifier,
    });
    removeLegacySessionKeyForDisplay(displayId);
    return;
  }
  localStorage.setItem(storageKey(displayId), JSON.stringify(session));
}

export function clearSession(displayId: string): void {
  clearDisplayAdoption(displayId);
  clearLegacySession(displayId);
}

export function clearAllSessions(): void {
  for (const display of loadDisplays()) {
    clearDisplayAdoption(display.id);
  }
  const keys: string[] = [];
  for (let i = 0; i < localStorage.length; i++) {
    const k = localStorage.key(i);
    if (k?.startsWith(SESSION_PREFIX)) {
      keys.push(k);
    }
  }
  for (const k of keys) {
    localStorage.removeItem(k);
  }
  for (let i = 0; i < sessionStorage.length; i++) {
    const k = sessionStorage.key(i);
    if (k?.startsWith(LEGACY_SESSION_PREFIX)) {
      sessionStorage.removeItem(k);
    }
  }
}
