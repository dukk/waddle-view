export const LIVE_PREVIEW_POP_OUT_BOUNDS_KEY = 'waddle_live_preview_popout_bounds_v1';

export const LIVE_PREVIEW_POP_OUT_DEFAULT_WIDTH = 1100;
export const LIVE_PREVIEW_POP_OUT_DEFAULT_HEIGHT = 780;

const MIN_WIDTH = 400;
const MIN_HEIGHT = 300;
const MAX_WIDTH = 3840;
const MAX_HEIGHT = 2160;

export type LivePreviewPopOutBounds = {
  width: number;
  height: number;
  left: number;
  top: number;
};

function clamp(n: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, n));
}

function normalizeBounds(raw: LivePreviewPopOutBounds): LivePreviewPopOutBounds | null {
  const width = clamp(Math.round(raw.width), MIN_WIDTH, MAX_WIDTH);
  const height = clamp(Math.round(raw.height), MIN_HEIGHT, MAX_HEIGHT);
  const left = Math.round(raw.left);
  const top = Math.round(raw.top);
  if (!Number.isFinite(width) || !Number.isFinite(height)) return null;
  if (!Number.isFinite(left) || !Number.isFinite(top)) return null;
  return { width, height, left, top };
}

export function loadLivePreviewPopOutBounds(): LivePreviewPopOutBounds | null {
  try {
    const raw = localStorage.getItem(LIVE_PREVIEW_POP_OUT_BOUNDS_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as Partial<LivePreviewPopOutBounds>;
    if (
      typeof parsed.width !== 'number' ||
      typeof parsed.height !== 'number' ||
      typeof parsed.left !== 'number' ||
      typeof parsed.top !== 'number'
    ) {
      return null;
    }
    return normalizeBounds(parsed as LivePreviewPopOutBounds);
  } catch {
    return null;
  }
}

export function saveLivePreviewPopOutBounds(bounds: LivePreviewPopOutBounds): void {
  const normalized = normalizeBounds(bounds);
  if (!normalized) return;
  try {
    localStorage.setItem(LIVE_PREVIEW_POP_OUT_BOUNDS_KEY, JSON.stringify(normalized));
  } catch {
    /* quota / private mode */
  }
}

/** Read size and screen position from the pop-out `window` (best effort). */
export function captureLivePreviewPopOutBounds(win: Window = window): LivePreviewPopOutBounds | null {
  const width = win.outerWidth;
  const height = win.outerHeight;
  const left = win.screenX ?? (win as Window & { screenLeft?: number }).screenLeft ?? NaN;
  const top = win.screenY ?? (win as Window & { screenTop?: number }).screenTop ?? NaN;
  return normalizeBounds({ width, height, left, top });
}
