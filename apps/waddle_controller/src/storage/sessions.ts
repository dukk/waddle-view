const SESSION_PREFIX = 'waddle_controller_session_v1:';

export type DisplaySession = {
  apiKey: string;
  identifier: string;
  role: string;
  permissions: string[];
  /** Client-side hint only; display does not expire API keys today. */
  expiresAtMs: number;
};

export function loadSession(displayId: string): DisplaySession | null {
  try {
    const raw = sessionStorage.getItem(`${SESSION_PREFIX}${displayId}`);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as DisplaySession;
    if (!parsed.apiKey || parsed.expiresAtMs <= Date.now()) {
      clearSession(displayId);
      return null;
    }
    return parsed;
  } catch {
    return null;
  }
}

export function saveSession(displayId: string, session: DisplaySession): void {
  sessionStorage.setItem(`${SESSION_PREFIX}${displayId}`, JSON.stringify(session));
}

export function clearSession(displayId: string): void {
  sessionStorage.removeItem(`${SESSION_PREFIX}${displayId}`);
}

export function clearAllSessions(): void {
  const keys: string[] = [];
  for (let i = 0; i < sessionStorage.length; i++) {
    const k = sessionStorage.key(i);
    if (k?.startsWith(SESSION_PREFIX)) {
      keys.push(k);
    }
  }
  for (const k of keys) {
    sessionStorage.removeItem(k);
  }
}
