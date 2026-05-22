import type { DisplayThemePreviewGroups } from '@/constants/displayThemePreview';

export type DisplayCustomTheme = {
  id: string;
  label: string;
  preview: DisplayThemePreviewGroups;
};

export const DISPLAY_THEME_CHROME_MIN_STOPS = 2;
export const DISPLAY_THEME_CHROME_MAX_STOPS = 4;
export const DISPLAY_THEME_ACCENT_COUNT = 4;

export const DEFAULT_DISPLAY_THEME_PREVIEW: DisplayThemePreviewGroups = {
  display: ['#0D1B2A', '#1B263B'],
  primaryContainer: ['#E0E1DD', '#1B263B', '#415A77'],
  secondaryContainer: ['#E0E1DD', '#415A77', '#778DA9'],
  accents: ['#83AF84', '#E05C6C', '#FFE356', '#966CB3'],
};

export type DisplayThemePickerOption = {
  id: string;
  label: string;
  preview: DisplayThemePreviewGroups;
  isCustom: boolean;
};
