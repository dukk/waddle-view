const SESSION_PREFIX = 'waddle_controller_session_v1:';

export type AuthUser = {
  id: string;
  username: string;
  display_name: string;
  role: string;
  is_bootstrap: boolean;
  disabled: boolean;
};

export type DisplaySession = {
  token: string;
  expiresAtMs: number;
  user: AuthUser;
  permissions: string[];
  warnings: string[];
};

export function loadSession(displayId: string): DisplaySession | null {
  try {
    const raw = sessionStorage.getItem(`${SESSION_PREFIX}${displayId}`);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as DisplaySession;
    if (parsed.expiresAtMs <= Date.now()) {
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
