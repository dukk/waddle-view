export const COLOR_MODE_STORAGE_KEY = 'waddle_controller_color_mode';

export type ColorModePreference = 'light' | 'dark' | 'system';

export function readColorModePreference(): ColorModePreference {
  try {
    const v = localStorage.getItem(COLOR_MODE_STORAGE_KEY);
    if (v === 'light' || v === 'dark' || v === 'system') return v;
  } catch {
    /* private mode / unavailable */
  }
  return 'system';
}

export function writeColorModePreference(value: ColorModePreference): void {
  try {
    localStorage.setItem(COLOR_MODE_STORAGE_KEY, value);
  } catch {
    /* ignore */
  }
}
