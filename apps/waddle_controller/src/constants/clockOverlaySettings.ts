/** Keep in sync with clock overlay placement in waddle_shared. */
export const CLOCK_OVERLAY_SCALE_MIN = 0.04;
export const CLOCK_OVERLAY_SCALE_MAX = 0.7;
export const CLOCK_OVERLAY_SCALE_DEFAULT = 0.2;
export const CLOCK_OVERLAY_POSITION_DEFAULT = 0.05;

export const ANALOG_CLOCK_OVERLAY_DIAL_LABELS = [
  'none',
  'numbers',
  'numeric',
  'roman',
  'roman_numerals',
  'cardinal_numbers',
  'cardinal',
  'crosshair_numbers',
] as const;

export const ANALOG_CLOCK_OVERLAY_HAND_ACCENTS = [
  'accent1',
  'accent2',
  'accent3',
  '1',
  '2',
  '3',
] as const;

export type ClockOverlayPlacementConfig = {
  x: number;
  y: number;
  scale: number;
  opacity?: number;
};

function clamp01(v: number, fallback: number): number {
  if (!Number.isFinite(v)) return fallback;
  return Math.min(1, Math.max(0, v));
}

function clampScale(v: number): number {
  if (!Number.isFinite(v)) return CLOCK_OVERLAY_SCALE_DEFAULT;
  return Math.min(CLOCK_OVERLAY_SCALE_MAX, Math.max(CLOCK_OVERLAY_SCALE_MIN, v));
}

export function readClockOverlayPlacement(raw: Record<string, unknown>): ClockOverlayPlacementConfig {
  const opacityRaw = raw.opacity;
  const opacity =
    typeof opacityRaw === 'number' && Number.isFinite(opacityRaw)
      ? clamp01(opacityRaw, 1)
      : undefined;
  const out: ClockOverlayPlacementConfig = {
    x: clamp01(typeof raw.x === 'number' ? raw.x : Number(raw.x), CLOCK_OVERLAY_POSITION_DEFAULT),
    y: clamp01(typeof raw.y === 'number' ? raw.y : Number(raw.y), CLOCK_OVERLAY_POSITION_DEFAULT),
    scale: clampScale(typeof raw.scale === 'number' ? raw.scale : Number(raw.scale)),
  };
  if (opacity !== undefined && opacity < 1) {
    out.opacity = opacity;
  }
  return out;
}
