import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import { fetchMe, loginDisplay, logoutDisplay } from '@/api/auth';
import { useDisplay } from '@/context/DisplayContext';
import {
  clearSession,
  loadSession,
  saveSession,
  type DisplaySession,
} from '@/storage/sessions';

type AuthCtx = {
  session: DisplaySession | null;
  login: (username: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  refreshSession: () => Promise<void>;
  hasPermission: (perm: string) => boolean;
  bootstrapWarning: boolean;
  needsLogin: boolean;
};

const Ctx = createContext<AuthCtx | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const { active } = useDisplay();
  const [session, setSession] = useState<DisplaySession | null>(() =>
    active ? loadSession(active.id) : null,
  );
  const syncFromStorage = useCallback(() => {
    if (!active) {
      setSession(null);
      return;
    }
    setSession(loadSession(active.id));
  }, [active]);

  useEffect(() => {
    syncFromStorage();
  }, [syncFromStorage]);

  const login = useCallback(
    async (username: string, password: string) => {
      if (!active) throw new Error('No display selected');
      const result = await loginDisplay(active.baseUrl, username, password);
      const stored: DisplaySession = {
        token: result.token,
        expiresAtMs: result.expiresAtMs,
        user: result.user,
        permissions: result.permissions,
        warnings: result.warnings,
      };
      saveSession(active.id, stored);
      setSession(stored);
    },
    [active],
  );

  const logout = useCallback(async () => {
    if (active && session) {
      await logoutDisplay(active.baseUrl, session.token);
      clearSession(active.id);
    }
    setSession(null);
  }, [active, session]);

  const refreshSession = useCallback(async () => {
    if (!active) return;
    const cur = loadSession(active.id);
    if (!cur) {
      setSession(null);
      return;
    }
    try {
      const me = await fetchMe(active.baseUrl, cur.token);
      const next: DisplaySession = { ...cur, ...me };
      saveSession(active.id, next);
      setSession(next);
    } catch {
      clearSession(active.id);
      setSession(null);
    }
  }, [active]);

  const value = useMemo(
    () => ({
      session,
      login,
      logout,
      refreshSession,
      hasPermission: (perm: string) => session?.permissions.includes(perm) ?? false,
      bootstrapWarning: session?.warnings.includes('bootstrap_admin') ?? false,
      needsLogin: active != null && session == null,
    }),
    [session, login, logout, refreshSession, active],
  );

  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

// eslint-disable-next-line react-refresh/only-export-components
export function useAuth(): AuthCtx {
  const v = useContext(Ctx);
  if (!v) throw new Error('useAuth outside AuthProvider');
  return v;
}
