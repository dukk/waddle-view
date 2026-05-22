import { useEffect, useState } from 'react';

import { useDisplay } from '@/context/DisplayContext';
import {
  fetchDisplayHealth,
  isDisplayPluginsNavEnabled,
  type DisplayReachability,
} from '@/util/displayHealth';

/** Whether Plugins nav/routes are enabled for the active display (from public health). */
export function useActiveDisplayPluginsNav(): {
  enabled: boolean;
  loading: boolean;
} {
  const { active } = useDisplay();
  const activeKey = active ? `${active.id}\0${active.baseUrl}` : '';
  const [reachability, setReachability] = useState<DisplayReachability | undefined>();
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!active) {
      setReachability(undefined);
      setLoading(false);
      return;
    }
    let cancelled = false;
    setLoading(true);
    setReachability(undefined);
    void fetchDisplayHealth(active).then((result) => {
      if (!cancelled) {
        setReachability(result);
        setLoading(false);
      }
    });
    return () => {
      cancelled = true;
    };
  }, [activeKey]);

  return {
    enabled: isDisplayPluginsNavEnabled(reachability),
    loading: Boolean(active) && loading,
  };
}
