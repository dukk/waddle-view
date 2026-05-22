import { useCallback, useEffect, useState } from 'react';
import { apiJson } from '@/api/client';
import type { SavedDisplay } from '@/storage/displays';
import { liveScreenLabelFromProgram, type NowPlayingInfo } from '@/util/liveScreenLabel';
import { latestProgramAtMs, programAtMs } from '@/util/programTelemetry';

type Items<T> = { items: T[] };

export type NowPlayingState = {
  info: NowPlayingInfo | null;
  loading: boolean;
  error: string | null;
  unavailable: boolean;
};

export function useNowPlayingScreen(
  display: SavedDisplay | null,
  options: {
    enabled: boolean;
    pollMs?: number;
    screenLabelById?: ReadonlyMap<string, string>;
    screenTypeDisplayLabel?: (screenType: string) => string;
  },
): NowPlayingState {
  const { enabled, pollMs = 5000, screenLabelById, screenTypeDisplayLabel } = options;
  const [info, setInfo] = useState<NowPlayingInfo | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    if (!display || !enabled) {
      setInfo(null);
      setError(null);
      setLoading(false);
      return;
    }
    setLoading(true);
    try {
      const res = await apiJson<Items<Record<string, unknown>>>(
        display,
        '/v1/telemetry/programs',
      );
      const items = res.items ?? [];
      const liveMs = latestProgramAtMs(items);
      const liveRow =
        liveMs != null ? items.find((row) => programAtMs(row) === liveMs) : undefined;
      const parsed = liveRow
        ? liveScreenLabelFromProgram(liveRow, {
            screenLabelById,
            screenTypeDisplayLabel,
          })
        : null;
      setInfo(parsed);
      setError(null);
    } catch (e) {
      setInfo(null);
      setError(String(e));
    } finally {
      setLoading(false);
    }
  }, [display, enabled, screenLabelById, screenTypeDisplayLabel]);

  useEffect(() => {
    if (!enabled || !display) {
      setInfo(null);
      setError(null);
      return;
    }
    let cancelled = false;
    const run = async () => {
      await refresh();
      if (cancelled) return;
    };
    void run();
    const id = window.setInterval(() => {
      void refresh();
    }, pollMs);
    return () => {
      cancelled = true;
      window.clearInterval(id);
    };
  }, [display, enabled, pollMs, refresh]);

  return {
    info,
    loading,
    error,
    unavailable: !enabled,
  };
}
