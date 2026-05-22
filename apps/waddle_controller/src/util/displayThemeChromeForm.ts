import type { DisplayThemePreviewGroups } from '@/constants/displayThemePreview';
import {
  DISPLAY_THEME_CHROME_MAX_STOPS,
  DISPLAY_THEME_CHROME_MIN_STOPS,
} from '@/constants/displayThemes';

const HEX_PATTERN = /^#[0-9A-Fa-f]{6}$/;

export type DisplayBackgroundFillMode = 'solid' | 'gradient';

/** Max gradient stops for display background (stored as 2 identical when solid). */
export const DISPLAY_BACKGROUND_GRADIENT_MAX = DISPLAY_THEME_CHROME_MAX_STOPS;

/** Max chrome gradient stops behind screen/ticker text (excluding foreground). */
export const CONTAINER_CHROME_GRADIENT_MAX =
  DISPLAY_THEME_CHROME_MAX_STOPS - 1;

export const CONTAINER_CHROME_GRADIENT_MIN = 1;

export function isValidThemeHex(raw: string): boolean {
  return HEX_PATTERN.test(raw.trim());
}

export function inferDisplayBackgroundMode(
  display: readonly string[],
): DisplayBackgroundFillMode {
  if (display.length < 2) {
    return 'solid';
  }
  if (display.length === 2 && display[0] === display[1]) {
    return 'solid';
  }
  return 'gradient';
}

export function displaySolidColor(display: readonly string[]): string {
  return display[0] ?? '#0D1B2A';
}

export function displayGradientStops(
  display: readonly string[],
  mode: DisplayBackgroundFillMode,
): string[] {
  if (mode === 'gradient') {
    if (display.length >= 2 && !(display.length === 2 && display[0] === display[1])) {
      return [...display];
    }
    const base = display[0] ?? '#0D1B2A';
    return [base, '#1B263B'];
  }
  const solid = displaySolidColor(display);
  return [solid, '#1B263B'];
}

export function buildDisplayStops(
  mode: DisplayBackgroundFillMode,
  solidColor: string,
  gradientStops: string[],
): string[] {
  if (mode === 'solid') {
    const c = solidColor;
    return [c, c];
  }
  const stops =
    gradientStops.length >= DISPLAY_THEME_CHROME_MIN_STOPS
      ? gradientStops.slice(0, DISPLAY_THEME_CHROME_MAX_STOPS)
      : [solidColor, solidColor];
  return stops;
}

export function splitContainerGroup(colors: readonly string[]): {
  foreground: string;
  chromeStops: string[];
} {
  const foreground = colors[0] ?? '#E0E1DD';
  const chromeStops =
    colors.length > 1 ? colors.slice(1) : [foreground];
  return { foreground, chromeStops };
}

export function joinContainerGroup(foreground: string, chromeStops: string[]): string[] {
  const stops =
    chromeStops.length >= CONTAINER_CHROME_GRADIENT_MIN
      ? chromeStops.slice(0, CONTAINER_CHROME_GRADIENT_MAX)
      : [foreground];
  return [foreground, ...stops].slice(0, DISPLAY_THEME_CHROME_MAX_STOPS);
}

export function isValidPreviewGroups(preview: DisplayThemePreviewGroups): boolean {
  const okHexList = (colors: readonly string[], min: number, max: number) =>
    colors.length >= min &&
    colors.length <= max &&
    colors.every((c) => isValidThemeHex(c));
  return (
    okHexList(preview.display, 2, 4) &&
    okHexList(preview.primaryContainer, 2, 4) &&
    okHexList(preview.secondaryContainer, 2, 4) &&
    preview.accents.length === 4 &&
    preview.accents.every((c) => isValidThemeHex(c))
  );
}
