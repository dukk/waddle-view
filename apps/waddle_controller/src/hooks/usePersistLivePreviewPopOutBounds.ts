import { useEffect } from 'react';
import {
  captureLivePreviewPopOutBounds,
  saveLivePreviewPopOutBounds,
} from '@/storage/livePreviewPopOutBounds';

const RESIZE_DEBOUNCE_MS = 400;

/** Persist pop-out window size and position while `/remote/view` is open. */
export function usePersistLivePreviewPopOutBounds(): void {
  useEffect(() => {
    const persist = () => {
      const bounds = captureLivePreviewPopOutBounds();
      if (bounds) saveLivePreviewPopOutBounds(bounds);
    };

    let resizeTimer: ReturnType<typeof setTimeout> | undefined;
    const onResize = () => {
      if (resizeTimer) clearTimeout(resizeTimer);
      resizeTimer = setTimeout(persist, RESIZE_DEBOUNCE_MS);
    };

    window.addEventListener('resize', onResize);
    window.addEventListener('beforeunload', persist);

    return () => {
      if (resizeTimer) clearTimeout(resizeTimer);
      window.removeEventListener('resize', onResize);
      window.removeEventListener('beforeunload', persist);
      persist();
    };
  }, []);
}
