import { useCallback, useEffect, useState } from 'react';
import { fetchControllerAbout, type AboutPayload } from '@/api/bffAbout';

export function useControllerAbout() {
  const [about, setAbout] = useState<AboutPayload | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const reload = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const body = await fetchControllerAbout();
      setAbout(body);
    } catch (e) {
      setAbout(null);
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void reload();
  }, [reload]);

  const versionLabel =
    about != null ? `${about.version}+${about.build}` : null;

  return { about, loading, error, reload, versionLabel };
}
