import { useCallback, useEffect, useRef, useState } from 'react';

import type { SavedDisplay } from '@/storage/displays';
import {
  fetchDisplayHealth,
  type DisplayReachability,
} from '@/util/displayHealth';

const POLL_MS = 30_000;

export type DisplaysReachabilityMap = Record<string, DisplayReachability>;

function initialMap(displays: SavedDisplay[]): DisplaysReachabilityMap {
  const out: DisplaysReachabilityMap = {};
  for (const d of displays) {
    out[d.id] = { state: 'checking' };
  }
  return out;
}

/** Polls `GET /v1/health` for each saved display (public, no API key). */
export function useDisplaysReachability(displays: SavedDisplay[]): DisplaysReachabilityMap {
  const [map, setMap] = useState<DisplaysReachabilityMap>(() => initialMap(displays));
  const displaysRef = useRef(displays);
  displaysRef.current = displays;

  const refresh = useCallback(async () => {
    const list = displaysRef.current;
    if (list.length === 0) {
      setMap({});
      return;
    }
    setMap((prev) => {
      const next = { ...prev };
      for (const d of list) {
        next[d.id] = { state: 'checking' };
      }
      return next;
    });
    const results = await Promise.all(
      list.map(async (d) => [d.id, await fetchDisplayHealth(d)] as const),
    );
    setMap(Object.fromEntries(results));
  }, []);

  const displayIdsKey = displays.map((d) => `${d.id}\0${d.baseUrl}`).join('|');

  useEffect(() => {
    void refresh();
    const id = window.setInterval(() => void refresh(), POLL_MS);
    return () => window.clearInterval(id);
  }, [refresh, displayIdsKey]);

  return map;
}
