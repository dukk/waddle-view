import { useEffect, useState } from 'react';
import type { SavedDisplay } from '@/storage/displays';
import { dismissActiveDisplayAlert, postDisplayNavigation } from '@/util/displayRemote';

type PermissionCheck = (permission: string) => boolean;

/**
 * Global arrow / Enter shortcuts for display remote control (slides, ticker, alerts).
 */
export function useDisplayRemoteShortcuts(
  display: SavedDisplay | null,
  hasPermission: PermissionCheck,
): { snack: string | null; clearSnack: () => void } {
  const [snack, setSnack] = useState<string | null>(null);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (!display) return;
      if (!hasPermission('navigation.control')) return;
      const t = e.target as HTMLElement | null;
      if (t && ['INPUT', 'TEXTAREA', 'SELECT'].includes(t.tagName)) return;
      if (t?.isContentEditable) return;
      let surface: 'screen' | 'ticker' | null = null;
      let direction: 'back' | 'forward' | null = null;
      if (e.key === 'ArrowLeft') {
        surface = 'screen';
        direction = 'back';
      } else if (e.key === 'ArrowRight') {
        surface = 'screen';
        direction = 'forward';
      } else if (e.key === 'ArrowUp') {
        surface = 'ticker';
        direction = 'back';
      } else if (e.key === 'ArrowDown') {
        surface = 'ticker';
        direction = 'forward';
      }
      if (surface && direction) {
        e.preventDefault();
        void (async () => {
          const err = await postDisplayNavigation(display, surface!, direction!);
          if (err) setSnack(err);
        })();
        return;
      }
      if (
        (e.key === 'Enter' || e.key === 'NumpadEnter') &&
        hasPermission('alerts.write')
      ) {
        e.preventDefault();
        void (async () => {
          const err = await dismissActiveDisplayAlert(display);
          if (err) setSnack(err);
        })();
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [display, hasPermission]);

  return { snack, clearSnack: () => setSnack(null) };
}
