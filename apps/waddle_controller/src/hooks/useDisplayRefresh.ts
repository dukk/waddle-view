import { useCallback, useRef, useState } from 'react';

/** Tracks in-flight display API loads so pages can show one shared refresh indicator. */
export function useDisplayRefresh(): {
  loading: boolean;
  wrapRefresh: <T>(fn: () => Promise<T>) => Promise<T>;
} {
  const inflightRef = useRef(0);
  const [loading, setLoading] = useState(false);

  const wrapRefresh = useCallback(async <T>(fn: () => Promise<T>): Promise<T> => {
    inflightRef.current += 1;
    if (inflightRef.current === 1) {
      setLoading(true);
    }
    try {
      return await fn();
    } finally {
      inflightRef.current = Math.max(0, inflightRef.current - 1);
      if (inflightRef.current === 0) {
        setLoading(false);
      }
    }
  }, []);

  return { loading, wrapRefresh };
}
