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
import { permissionsForRole, PREVIEWABLE_CONTROLLER_ROLES } from '@/auth/rolePermissions';

type AuthCtx = {
  session: DisplaySession | null;
  login: (username: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  refreshSession: () => Promise<void>;
  hasPermission: (perm: string) => boolean;
  /** Role for UI + routing (admin “view as” preview overrides actual role). */
  effectiveRole: string | null;
  /** Viewer or power viewer: operator sidebar is trimmed; allowed routes are enforced in `ProgramsOnlyOutlet`. */
  isProgramsOnlyControllerUser: boolean;
  bootstrapWarning: boolean;
  needsLogin: boolean;
  /** Sign-in dialog is open because it is required or the user asked to sign in again. */
  loginDialogOpen: boolean;
  openLoginDialog: () => void;
  closeLoginDialog: () => void;
  /** Signed-in user is an administrator (not affected by UI preview). */
  isAdminUser: boolean;
  /** When set, the controller UI treats permissions as this role (admin preview only). */
  viewAsRole: string | null;
  setViewAsRole: (role: string) => void;
  clearViewAsRole: () => void;
};

const Ctx = createContext<AuthCtx | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const { active } = useDisplay();
  const [loginDialogForced, setLoginDialogForced] = useState(false);
  const [viewAsRole, setViewAsRoleState] = useState<string | null>(null);
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

  useEffect(() => {
    setViewAsRoleState(null);
  }, [active?.id]);

  useEffect(() => {
    if (!active) {
      setLoginDialogForced(false);
    }
  }, [active]);

  const isAdminUser = session?.user.role === 'admin';

  useEffect(() => {
    if (!isAdminUser) setViewAsRoleState(null);
  }, [isAdminUser]);

  const openLoginDialog = useCallback(() => {
    if (active) {
      setLoginDialogForced(true);
    }
  }, [active]);

  const closeLoginDialog = useCallback(() => {
    setLoginDialogForced(false);
  }, []);

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
      setLoginDialogForced(false);
    },
    [active],
  );

  const logout = useCallback(async () => {
    if (active && session) {
      await logoutDisplay(active.baseUrl, session.token);
      clearSession(active.id);
    }
    setSession(null);
    setViewAsRoleState(null);
    setLoginDialogForced(false);
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

  const needsLogin = active != null && session == null;
  const loginDialogOpen = Boolean(active && (needsLogin || loginDialogForced));

  const previewPermissions = useMemo(() => {
    if (!session || !isAdminUser || !viewAsRole) return null;
    return permissionsForRole(viewAsRole);
  }, [session, isAdminUser, viewAsRole]);

  const effectiveRole = useMemo(() => {
    if (!session) return null;
    if (isAdminUser && viewAsRole) return viewAsRole;
    return session.user.role;
  }, [session, isAdminUser, viewAsRole]);

  const isProgramsOnlyControllerUser =
    effectiveRole === 'viewer' || effectiveRole === 'power_viewer';

  const setViewAsRole = useCallback(
    (role: string) => {
      if (!isAdminUser) return;
      if (!(PREVIEWABLE_CONTROLLER_ROLES as readonly string[]).includes(role)) return;
      setViewAsRoleState(role);
    },
    [isAdminUser],
  );

  const clearViewAsRole = useCallback(() => {
    setViewAsRoleState(null);
  }, []);

  const value = useMemo(
    () => ({
      session,
      login,
      logout,
      refreshSession,
      hasPermission: (perm: string) => {
        if (!session) return false;
        if (previewPermissions) return previewPermissions.includes(perm);
        return session.permissions.includes(perm);
      },
      effectiveRole,
      isProgramsOnlyControllerUser,
      bootstrapWarning: session?.warnings.includes('bootstrap_admin') ?? false,
      needsLogin,
      loginDialogOpen,
      openLoginDialog,
      closeLoginDialog,
      isAdminUser,
      viewAsRole: isAdminUser ? viewAsRole : null,
      setViewAsRole,
      clearViewAsRole,
    }),
    [
      session,
      login,
      logout,
      refreshSession,
      previewPermissions,
      effectiveRole,
      isProgramsOnlyControllerUser,
      needsLogin,
      loginDialogOpen,
      openLoginDialog,
      closeLoginDialog,
      isAdminUser,
      viewAsRole,
      setViewAsRole,
      clearViewAsRole,
    ],
  );

  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

// eslint-disable-next-line react-refresh/only-export-components
export function useAuth(): AuthCtx {
  const v = useContext(Ctx);
  if (!v) throw new Error('useAuth outside AuthProvider');
  return v;
}
