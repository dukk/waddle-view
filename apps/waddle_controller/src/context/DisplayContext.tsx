import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import {
  addDisplay,
  DISPLAYS_CHANGED_EVENT,
  loadDisplays,
  removeDisplay as removeStoredDisplay,
  type SavedDisplay,
  saveDisplays,
  updateDisplaySettings,
} from '@/storage/displays';
import { clearSession, loadSession } from '@/storage/sessions';
import { syncUserDisplayToServer } from '@/storage/userDisplaysSync';
import { setActiveUserDisplay } from '@/api/bffUserDisplays';
import { BffError } from '@/api/bffClient';
import { isDisplayProxyAuthEnabled } from '@/api/displayAuthMode';

type DisplayCtx = {
  displays: SavedDisplay[];
  active: SavedDisplay | null;
  setActiveId: (id: string) => void;
  refresh: () => void;
  addNewDisplay: (input: { baseUrl: string; label?: string }) => void;
  replaceDisplays: (next: SavedDisplay[]) => void;
  removeDisplay: (id: string) => void;
  updateDisplay: (
    id: string,
    input: { label: string; baseUrl: string },
  ) => Promise<void>;
};

const Ctx = createContext<DisplayCtx | null>(null);

export function DisplayProvider({ children }: { children: ReactNode }) {
  const [displays, setDisplays] = useState<SavedDisplay[]>(() => loadDisplays());
  const [activeId, setActiveId] = useState<string | null>(() => displays[0]?.id ?? null);

  const refresh = useCallback(() => {
    const next = loadDisplays();
    setDisplays(next);
    setActiveId((cur) => {
      if (!cur || !next.some((d) => d.id === cur)) {
        const activeRemote = next[0]?.id ?? null;
        return activeRemote;
      }
      return cur;
    });
  }, []);

  useEffect(() => {
    const onChanged = () => refresh();
    window.addEventListener(DISPLAYS_CHANGED_EVENT, onChanged);
    return () => window.removeEventListener(DISPLAYS_CHANGED_EVENT, onChanged);
  }, [refresh]);

  const active = useMemo(
    () => displays.find((d) => d.id === activeId) ?? null,
    [displays, activeId],
  );

  const addNewDisplay = useCallback(
    (input: { baseUrl: string; label?: string }) => {
      const d = addDisplay(input);
      setDisplays(loadDisplays());
      setActiveId(d.id);
    },
    [],
  );

  const replaceDisplays = useCallback((next: SavedDisplay[]) => {
    saveDisplays(next);
    setDisplays(next);
    setActiveId(next[0]?.id ?? null);
  }, []);

  const removeDisplay = useCallback((id: string) => {
    clearSession(id);
    removeStoredDisplay(id);
    const next = loadDisplays();
    setDisplays(next);
    setActiveId((cur) => {
      const still = cur != null && next.some((d) => d.id === cur);
      if (still) {
        return cur;
      }
      return next[0]?.id ?? null;
    });
  }, []);

  const selectActiveId = useCallback((id: string) => {
    setActiveId(id);
    if (isDisplayProxyAuthEnabled()) {
      void setActiveUserDisplay(id).catch((e) => {
        if (e instanceof BffError && (e.status === 401 || e.status === 403)) return;
      });
    }
  }, []);

  const updateDisplay = useCallback(
    async (id: string, input: { label: string; baseUrl: string }) => {
      const updated = updateDisplaySettings(id, input);
      if (!updated) {
        throw new Error('Invalid display label or base URL');
      }
      setDisplays(loadDisplays());
      const session = loadSession(id);
      if (session) {
        await syncUserDisplayToServer(updated, session).catch((e) => {
          if (e instanceof BffError && (e.status === 401 || e.status === 403)) return;
          throw e;
        });
      }
    },
    [],
  );

  const value = useMemo(
    () => ({
      displays,
      active,
      setActiveId: selectActiveId,
      refresh,
      addNewDisplay,
      replaceDisplays,
      removeDisplay,
      updateDisplay,
    }),
    [
      displays,
      active,
      refresh,
      addNewDisplay,
      replaceDisplays,
      removeDisplay,
      selectActiveId,
      updateDisplay,
    ],
  );

  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

// Colocated hook + provider; splitting only for fast-refresh is not worth the extra module.
// eslint-disable-next-line react-refresh/only-export-components -- useDisplay is a hook, not a component
export function useDisplay(): DisplayCtx {
  const v = useContext(Ctx);
  if (!v) throw new Error('useDisplay outside DisplayProvider');
  return v;
}
