import {
  createContext,
  useCallback,
  useContext,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import {
  addDisplay,
  loadDisplays,
  removeDisplay as removeStoredDisplay,
  type SavedDisplay,
  saveDisplays,
} from '@/storage/displays';

type DisplayCtx = {
  displays: SavedDisplay[];
  active: SavedDisplay | null;
  setActiveId: (id: string) => void;
  refresh: () => void;
  addNewDisplay: (input: { baseUrl: string; label?: string }) => void;
  replaceDisplays: (next: SavedDisplay[]) => void;
  removeDisplay: (id: string) => void;
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
        return next[0]?.id ?? null;
      }
      return cur;
    });
  }, []);

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

  const value = useMemo(
    () => ({
      displays,
      active,
      setActiveId: (id: string) => setActiveId(id),
      refresh,
      addNewDisplay,
      replaceDisplays,
      removeDisplay,
    }),
    [displays, active, refresh, addNewDisplay, replaceDisplays, removeDisplay],
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
