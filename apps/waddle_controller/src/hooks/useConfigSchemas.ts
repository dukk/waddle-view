import { useEffect, useState } from 'react';
import { ensureConfigSchemasCached } from '@/api/configSchemas';
import type { SavedDisplay } from '@/storage/displays';
import {
  loadConfigSchemas,
  type ConfigSchemasBundle,
} from '@/storage/configSchemaCache';

export function useConfigSchemas(active: SavedDisplay | null): {
  schemas: ConfigSchemasBundle | null;
  loading: boolean;
  error: string | null;
} {
  const [schemas, setSchemas] = useState<ConfigSchemasBundle | null>(() =>
    active ? loadConfigSchemas(active.id) : null,
  );
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const displayId = active?.id ?? null;

  useEffect(() => {
    if (!active || !displayId) {
      setSchemas(null);
      setError(null);
      setLoading(false);
      return;
    }
    const cached = loadConfigSchemas(displayId);
    if (cached) {
      setSchemas(cached);
      setError(null);
      setLoading(false);
      return;
    }
    let cancelled = false;
    setLoading(true);
    setError(null);
    void ensureConfigSchemasCached(active)
      .then((bundle) => {
        if (!cancelled) {
          setSchemas(bundle);
        }
      })
      .catch((e) => {
        if (!cancelled) {
          setError(e instanceof Error ? e.message : String(e));
          setSchemas(null);
        }
      })
      .finally(() => {
        if (!cancelled) {
          setLoading(false);
        }
      });
    return () => {
      cancelled = true;
    };
  }, [active, displayId]);

  return { schemas, loading, error };
}
