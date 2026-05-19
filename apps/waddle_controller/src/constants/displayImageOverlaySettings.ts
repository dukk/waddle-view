/** Keep in sync with `kDisplayImageOverlayScaleMin` / `Max` in waddle_shared. */
export const DISPLAY_IMAGE_OVERLAY_SCALE_MIN = 0.04;
export const DISPLAY_IMAGE_OVERLAY_SCALE_MAX = 0.7;
export const DISPLAY_IMAGE_OVERLAY_SCALE_DEFAULT = 0.12;
export const DISPLAY_IMAGE_OVERLAY_POSITION_DEFAULT = 0.05;

export type DisplayImageOverlaySettings = {
  enabled: boolean;
  image_blob_key?: string;
  x: number;
  y: number;
  scale: number;
  opacity?: number;
};

export const DEFAULT_DISPLAY_IMAGE_OVERLAY: DisplayImageOverlaySettings = {
  enabled: false,
  x: DISPLAY_IMAGE_OVERLAY_POSITION_DEFAULT,
  y: DISPLAY_IMAGE_OVERLAY_POSITION_DEFAULT,
  scale: DISPLAY_IMAGE_OVERLAY_SCALE_DEFAULT,
};

function clamp01(v: number, fallback: number): number {
  if (!Number.isFinite(v)) return fallback;
  return Math.min(1, Math.max(0, v));
}

function clampScale(v: number): number {
  if (!Number.isFinite(v)) return DISPLAY_IMAGE_OVERLAY_SCALE_DEFAULT;
  return Math.min(
    DISPLAY_IMAGE_OVERLAY_SCALE_MAX,
    Math.max(DISPLAY_IMAGE_OVERLAY_SCALE_MIN, v),
  );
}

export function normalizeDisplayImageOverlay(raw: unknown): DisplayImageOverlaySettings {
  if (!raw || typeof raw !== 'object') {
    return { ...DEFAULT_DISPLAY_IMAGE_OVERLAY };
  }
  const o = raw as Record<string, unknown>;
  const blob =
    typeof o.image_blob_key === 'string' && o.image_blob_key.trim()
      ? o.image_blob_key.trim()
      : undefined;
  const opacityRaw = o.opacity;
  const opacity =
    typeof opacityRaw === 'number' && Number.isFinite(opacityRaw)
      ? clamp01(opacityRaw, 1)
      : undefined;
  const out: DisplayImageOverlaySettings = {
    enabled: o.enabled === true,
    x: clamp01(typeof o.x === 'number' ? o.x : Number(o.x), DISPLAY_IMAGE_OVERLAY_POSITION_DEFAULT),
    y: clamp01(typeof o.y === 'number' ? o.y : Number(o.y), DISPLAY_IMAGE_OVERLAY_POSITION_DEFAULT),
    scale: clampScale(typeof o.scale === 'number' ? o.scale : Number(o.scale)),
  };
  if (blob) {
    out.image_blob_key = blob;
  }
  if (opacity !== undefined && opacity < 1) {
    out.opacity = opacity;
  }
  return out;
}
