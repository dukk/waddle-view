import {
  createContext,
  useCallback,
  useContext,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import { CssBaseline, ThemeProvider, useMediaQuery } from '@mui/material';
import { createAppTheme } from '@/theme';
import {
  readColorModePreference,
  writeColorModePreference,
  type ColorModePreference,
} from '@/storage/colorModePreference';

type ColorModeContextValue = {
  preference: ColorModePreference;
  setPreference: (value: ColorModePreference) => void;
  /** Resolved palette mode after applying system preference. */
  resolvedMode: 'light' | 'dark';
};

const ColorModeContext = createContext<ColorModeContextValue | null>(null);

// eslint-disable-next-line react-refresh/only-export-components -- useColorMode is a hook, not a component
export function useColorMode(): ColorModeContextValue {
  const ctx = useContext(ColorModeContext);
  if (!ctx) {
    throw new Error('useColorMode must be used within ColorModeProvider');
  }
  return ctx;
}

export function ColorModeProvider({ children }: { children: ReactNode }) {
  const [preference, setPreferenceState] = useState<ColorModePreference>(() =>
    readColorModePreference(),
  );
  const prefersDark = useMediaQuery('(prefers-color-scheme: dark)');
  const resolvedMode: 'light' | 'dark' =
    preference === 'system' ? (prefersDark ? 'dark' : 'light') : preference;

  const setPreference = useCallback((value: ColorModePreference) => {
    setPreferenceState(value);
    writeColorModePreference(value);
  }, []);

  const theme = useMemo(() => createAppTheme(resolvedMode), [resolvedMode]);

  const value = useMemo(
    () => ({ preference, setPreference, resolvedMode }),
    [preference, setPreference, resolvedMode],
  );

  return (
    <ColorModeContext.Provider value={value}>
      <ThemeProvider theme={theme}>
        <CssBaseline />
        {children}
      </ThemeProvider>
    </ColorModeContext.Provider>
  );
}
