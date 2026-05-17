import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import { confirmAdoption, sessionFromAdoption } from '@/api/adoption';
import { normalizeAdoptionChallengeCode } from '@/util/adoptionChallengeCode';
import { adoptionError, adoptionLog } from '@/util/adoptionLog';
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
  completeAdoption: (identifier: string, challengeCode: string) => Promise<void>;
  saveAdoptionSession: (session: DisplaySession) => void;
  logout: () => void;
  hasPermission: (perm: string) => boolean;
  effectiveRole: string | null;
  isProgramsOnlyControllerUser: boolean;
  needsLogin: boolean;
  loginDialogOpen: boolean;
  openLoginDialog: () => void;
  closeLoginDialog: () => void;
  isAdminUser: boolean;
  viewAsRole: string | null;
  setViewAsRole: (role: string) => void;
  clearViewAsRole: () => void;
};

const Ctx = createContext<AuthCtx | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const { active } = useDisplay();
  const [loginDialogForced, setLoginDialogForced] = useState(false);
  const [loginDismissedDisplayId, setLoginDismissedDisplayId] = useState<string | null>(null);
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
    setLoginDismissedDisplayId(null);
  }, [active?.id]);

  useEffect(() => {
    if (!active) {
      setLoginDialogForced(false);
    }
  }, [active]);

  const isAdminUser = session?.role === 'admin';

  useEffect(() => {
    if (!isAdminUser) setViewAsRoleState(null);
  }, [isAdminUser]);

  const openLoginDialog = useCallback(() => {
    if (active) {
      setLoginDismissedDisplayId(null);
      setLoginDialogForced(true);
    }
  }, [active]);

  const closeLoginDialog = useCallback(() => {
    setLoginDialogForced(false);
    if (active) {
      setLoginDismissedDisplayId(active.id);
    }
  }, [active]);

  const saveAdoptionSession = useCallback(
    (next: DisplaySession) => {
      if (!active) return;
      saveSession(active.id, next);
      setSession(next);
      setLoginDialogForced(false);
    },
    [active],
  );

  const completeAdoption = useCallback(
    async (identifier: string, challengeCode: string) => {
      if (!active) throw new Error('No display selected');
      adoptionLog('ui.loginDialog.confirm.start', 're-adopting active display', {
        displayId: active.id,
        baseUrl: active.baseUrl,
        identifier,
        challenge_code: challengeCode,
      });
      try {
        const result = await confirmAdoption(active.baseUrl, {
          identifier,
          challenge_code: normalizeAdoptionChallengeCode(challengeCode),
        });
        const stored = sessionFromAdoption(active.baseUrl, result);
        saveSession(active.id, stored);
        setSession(stored);
        setLoginDialogForced(false);
        adoptionLog('ui.loginDialog.confirm.success', 'session updated for display', {
          displayId: active.id,
          role: stored.role,
        });
      } catch (e) {
        adoptionError('ui.loginDialog.confirm.failed', 're-adoption failed', {
          displayId: active.id,
          error: e instanceof Error ? e.message : String(e),
        });
        throw e;
      }
    },
    [active],
  );

  const logout = useCallback(() => {
    if (active) {
      clearSession(active.id);
    }
    setSession(null);
    setViewAsRoleState(null);
    setLoginDialogForced(false);
  }, [active]);

  const needsLogin = active != null && session == null;
  const loginDialogOpen = Boolean(
    active &&
      (loginDialogForced || (needsLogin && loginDismissedDisplayId !== active.id)),
  );

  const previewPermissions = useMemo(() => {
    if (!session || !isAdminUser || !viewAsRole) return null;
    return permissionsForRole(viewAsRole);
  }, [session, isAdminUser, viewAsRole]);

  const effectiveRole = useMemo(() => {
    if (!session) return null;
    if (isAdminUser && viewAsRole) return viewAsRole;
    return session.role;
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
      completeAdoption,
      saveAdoptionSession,
      logout,
      hasPermission: (perm: string) => {
        if (!session) return false;
        if (previewPermissions) return previewPermissions.includes(perm);
        return session.permissions.includes(perm);
      },
      effectiveRole,
      isProgramsOnlyControllerUser,
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
      completeAdoption,
      saveAdoptionSession,
      logout,
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
