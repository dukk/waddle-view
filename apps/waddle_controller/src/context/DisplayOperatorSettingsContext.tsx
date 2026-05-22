import { createContext, useContext, type ReactNode } from 'react';
import {
  useDisplayOperatorSettings,
  type DisplayOperatorSettingsState,
} from '@/hooks/useDisplayOperatorSettings';
import type { SavedDisplay } from '@/storage/displays';

const DisplayOperatorSettingsContext = createContext<DisplayOperatorSettingsState | null>(
  null,
);

export function DisplayOperatorSettingsProvider({
  display,
  kvWriteTick,
  onKvChanged,
  children,
}: {
  display: SavedDisplay;
  kvWriteTick: number;
  onKvChanged: () => void;
  children: ReactNode;
}) {
  const settings = useDisplayOperatorSettings(display, kvWriteTick, onKvChanged);
  return (
    <DisplayOperatorSettingsContext.Provider value={settings}>
      {children}
    </DisplayOperatorSettingsContext.Provider>
  );
}

export function useDisplayOperatorSettingsContext(): DisplayOperatorSettingsState | null {
  return useContext(DisplayOperatorSettingsContext);
}
