import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import { fetchDisplaySettings } from '@/api/displaySettings';
import { ApiError } from '@/api/client';
import type { DisplaySettings } from '@/constants/displaySettings';
import { useAuth } from '@/context/AuthContext';
import { useDisplay } from '@/context/DisplayContext';
import {
  dateTimeFormatPrefsFromDisplaySettings,
  formatControllerDate,
  formatControllerDateTime,
  formatControllerDateTimeWithMs,
  formatControllerTime,
  formatControllerTimestamp,
  type DateTimeFormatPrefs,
} from '@/util/dateTimeFormat';

type DisplayFormatContextValue = {
  settings: DisplaySettings | null;
  prefs: DateTimeFormatPrefs;
  loading: boolean;
  refresh: () => Promise<void>;
  formatDate: (d: Date) => string;
  formatTime: (d: Date) => string;
  formatDateTime: (d: Date) => string;
  formatDateTimeWithMs: (d: Date) => string;
  formatTimestamp: (atMs: unknown) => string;
};

const DisplayFormatContext = createContext<DisplayFormatContextValue | null>(null);

// eslint-disable-next-line react-refresh/only-export-components -- hook export
export function useDisplayFormat(): DisplayFormatContextValue {
  const ctx = useContext(DisplayFormatContext);
  if (!ctx) {
    throw new Error('useDisplayFormat must be used within DisplayFormatProvider');
  }
  return ctx;
}

export function DisplayFormatProvider({ children }: { children: ReactNode }) {
  const { active } = useDisplay();
  const { hasPermission } = useAuth();
  const canRead = hasPermission('curator.read');
  const [settings, setSettings] = useState<DisplaySettings | null>(null);
  const [loading, setLoading] = useState(false);

  const prefs = useMemo(
    () => dateTimeFormatPrefsFromDisplaySettings(settings),
    [settings],
  );

  const refresh = useCallback(async () => {
    if (!active || !canRead) {
      setSettings(null);
      return;
    }
    setLoading(true);
    try {
      const data = await fetchDisplaySettings(active);
      setSettings(data);
    } catch (e) {
      if (!(e instanceof ApiError && e.status === 403)) {
        setSettings(null);
      }
    } finally {
      setLoading(false);
    }
  }, [active, canRead]);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  const value = useMemo((): DisplayFormatContextValue => {
    const formatDate = (d: Date) => formatControllerDate(d, prefs);
    const formatTime = (d: Date) => formatControllerTime(d, prefs);
    const formatDateTime = (d: Date) => formatControllerDateTime(d, prefs);
    const formatDateTimeWithMs = (d: Date) => formatControllerDateTimeWithMs(d, prefs);
    const formatTimestamp = (atMs: unknown) => formatControllerTimestamp(atMs, prefs);
    return {
      settings,
      prefs,
      loading,
      refresh,
      formatDate,
      formatTime,
      formatDateTime,
      formatDateTimeWithMs,
      formatTimestamp,
    };
  }, [settings, prefs, loading, refresh]);

  return (
    <DisplayFormatContext.Provider value={value}>{children}</DisplayFormatContext.Provider>
  );
}
