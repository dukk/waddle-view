import type { SavedDisplay } from '@/storage/displays';

export const ACTIVE_DISPLAY_STORAGE_KEY = 'waddle_controller_active_display_v1';

export function readActiveDisplayPreference(): string | null {
  try {
    const v = localStorage.getItem(ACTIVE_DISPLAY_STORAGE_KEY);
    if (typeof v === 'string' && v.length > 0) return v;
  } catch {
    /* private mode / unavailable */
  }
  return null;
}

export function writeActiveDisplayPreference(displayId: string | null): void {
  try {
    if (displayId == null) {
      localStorage.removeItem(ACTIVE_DISPLAY_STORAGE_KEY);
    } else {
      localStorage.setItem(ACTIVE_DISPLAY_STORAGE_KEY, displayId);
    }
  } catch {
    /* ignore */
  }
}

/** Last-selected display when still in the list; otherwise the first display. */
export function resolveActiveDisplayId(displays: SavedDisplay[]): string | null {
  const stored = readActiveDisplayPreference();
  if (stored && displays.some((d) => d.id === stored)) {
    return stored;
  }
  return displays[0]?.id ?? null;
}
