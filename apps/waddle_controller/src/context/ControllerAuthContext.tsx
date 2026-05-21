import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import {
  bffBootstrapAdmin,
  bffLogin,
  bffLogout,
  fetchBffStatus,
  type BffStatus,
} from '@/api/bffAuth';
import { BffError } from '@/api/bffClient';
import { setDisplayProxyAuthEnabled } from '@/api/displayAuthMode';
import { clearLocalDisplaysMigrationComplete } from '@/storage/displays';
import { pullUserDisplaysFromServer } from '@/storage/userDisplaysSync';

type ControllerAuthCtx = {
  status: BffStatus | null;
  loading: boolean;
  error: string | null;
  refresh: () => Promise<void>;
  login: (username: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  bootstrapAdmin: (username: string, password: string) => Promise<void>;
  isControllerAdmin: boolean;
};

const Ctx = createContext<ControllerAuthCtx | null>(null);

const PUBLIC_PATHS = new Set([
  '/controller-login',
  '/controller-bootstrap',
  '/controller-change-password',
]);

export function isUserModeActive(status: BffStatus): boolean {
  return status.userModeEnabled ?? status.userManagementEnabled ?? false;
}

export function ControllerAuthProvider({ children }: { children: ReactNode }) {
  const [status, setStatus] = useState<BffStatus | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const navigate = useNavigate();
  const location = useLocation();

  const refresh = useCallback(async () => {
    setError(null);
    try {
      const next = await fetchBffStatus();
      setStatus(next);
      setDisplayProxyAuthEnabled(isUserModeActive(next));
      if (!isUserModeActive(next)) {
        clearLocalDisplaysMigrationComplete();
      } else if (next.user) {
        await pullUserDisplaysFromServer();
      }
    } catch (e) {
      const offline =
        e instanceof TypeError ||
        (e instanceof Error && /failed to fetch|network/i.test(e.message));
      if (offline) {
        setStatus({
          authEnabled: false,
          userModeEnabled: false,
          userManagementEnabled: false,
          needsBootstrap: false,
          recoveryExportAvailable: false,
        });
        return;
      }
      setStatus(null);
      setError(e instanceof Error ? e.message : String(e));
    }
  }, []);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      setLoading(true);
      await refresh();
      if (!cancelled) setLoading(false);
    })();
    return () => {
      cancelled = true;
    };
  }, [refresh]);

  const redirectForGate = useCallback(
    (next: BffStatus) => {
      const path = location.pathname;
      if (PUBLIC_PATHS.has(path)) return;
      const userMode = isUserModeActive(next);
      if (userMode && next.needsBootstrap) {
        navigate('/controller-bootstrap', { replace: true });
        return;
      }
      if (userMode && !next.user) {
        navigate('/controller-login', { replace: true });
        return;
      }
      if (userMode && next.user?.mustChangePassword && path !== '/controller-change-password') {
        navigate('/controller-change-password', { replace: true });
      }
    },
    [location.pathname, navigate],
  );

  useEffect(() => {
    if (!status || loading) return;
    redirectForGate(status);
  }, [status, loading, redirectForGate]);

  const login = useCallback(
    async (username: string, password: string) => {
      const res = await bffLogin(username, password);
      await refresh();
      if (res.user.mustChangePassword) {
        navigate('/controller-change-password', { replace: true });
      } else {
        navigate('/', { replace: true });
      }
    },
    [navigate, refresh],
  );

  const logout = useCallback(async () => {
    try {
      await bffLogout();
    } catch (e) {
      if (!(e instanceof BffError) || e.status !== 401) throw e;
    }
    await refresh();
    if (status && isUserModeActive(status)) {
      navigate('/controller-login', { replace: true });
    }
  }, [navigate, refresh, status]);

  const bootstrapAdmin = useCallback(
    async (username: string, password: string) => {
      await bffBootstrapAdmin(username, password);
      await refresh();
      navigate('/', { replace: true });
    },
    [navigate, refresh],
  );

  const value = useMemo<ControllerAuthCtx>(
    () => ({
      status,
      loading,
      error,
      refresh,
      login,
      logout,
      bootstrapAdmin,
      isControllerAdmin: status?.user?.role === 'admin',
    }),
    [status, loading, error, refresh, login, logout, bootstrapAdmin],
  );

  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

// eslint-disable-next-line react-refresh/only-export-components -- useControllerAuth is a hook, not a component
export function useControllerAuth(): ControllerAuthCtx {
  const ctx = useContext(Ctx);
  if (!ctx) throw new Error('useControllerAuth requires ControllerAuthProvider');
  return ctx;
}

export function ControllerAuthGate({ children }: { children: ReactNode }) {
  const { status, loading, error } = useControllerAuth();
  const location = useLocation();

  if (loading) return null;

  if (error && !status) {
    return <div role="alert">{error}</div>;
  }

  if (!status) return null;

  if (PUBLIC_PATHS.has(location.pathname)) {
    return <>{children}</>;
  }

  const userMode = isUserModeActive(status);

  if (userMode && status.needsBootstrap) {
    return null;
  }

  if (userMode && !status.user) {
    return null;
  }

  if (userMode && status.user?.mustChangePassword) {
    return null;
  }

  return <>{children}</>;
}
