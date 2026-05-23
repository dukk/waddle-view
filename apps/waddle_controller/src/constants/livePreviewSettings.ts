export const DEFAULT_LIVE_PREVIEW_FPS = 10;
export const DEFAULT_LIVE_PREVIEW_WIDTH = 720;
export const DEFAULT_LIVE_PREVIEW_QUALITY = 50;

/** Matches [kDisplayLivePreviewWidthPresets] in waddle_shared. */
export const LIVE_PREVIEW_WIDTH_PRESETS = [
  3840, 2560, 1920, 1680, 1600, 1280, 1024, 800, 720, 640,
] as const;

export type LivePreviewWidthPreset = (typeof LIVE_PREVIEW_WIDTH_PRESETS)[number];

export const LIVE_PREVIEW_WIDTH_OPTIONS: ReadonlyArray<{
  value: LivePreviewWidthPreset;
  label: string;
}> = [
  { value: 3840, label: '3840 px — 16:9 (4K UHD)' },
  { value: 2560, label: '2560 px — 16:9 (QHD) / 16:10 (WQXGA)' },
  { value: 1920, label: '1920 px — 16:9 (FHD) / 16:10 (WUXGA)' },
  { value: 1680, label: '1680 px — 16:10 (WSXGA+)' },
  { value: 1600, label: '1600 px — 16:10 (WSXGA)' },
  { value: 1280, label: '1280 px — 16:9 (HD) / 16:10 (WXGA)' },
  { value: 1024, label: '1024 px — 4:3 (XGA)' },
  { value: 800, label: '800 px — 4:3 (SVGA)' },
  { value: 720, label: '720 px — 16:9 (HD, default)' },
  { value: 640, label: '640 px — 4:3 (VGA)' },
];

export function snapLivePreviewWidth(value: number): LivePreviewWidthPreset {
  let best: LivePreviewWidthPreset = LIVE_PREVIEW_WIDTH_PRESETS[0];
  let bestDelta = Math.abs(value - best);
  for (const preset of LIVE_PREVIEW_WIDTH_PRESETS) {
    const delta = Math.abs(value - preset);
    if (delta < bestDelta) {
      best = preset;
      bestDelta = delta;
    }
  }
  return best;
}

export function normalizeLivePreviewWidth(raw: unknown): LivePreviewWidthPreset {
  if (typeof raw === 'number' && Number.isFinite(raw)) {
    const clamped = Math.min(3840, Math.max(320, Math.round(raw)));
    return snapLivePreviewWidth(clamped);
  }
  if (typeof raw === 'string' && raw.trim() !== '') {
    const parsed = Number.parseInt(raw.trim(), 10);
    if (Number.isFinite(parsed)) {
      return snapLivePreviewWidth(parsed);
    }
  }
  return DEFAULT_LIVE_PREVIEW_WIDTH;
}

export function isLivePreviewWidthPreset(value: number): value is LivePreviewWidthPreset {
  return (LIVE_PREVIEW_WIDTH_PRESETS as readonly number[]).includes(value);
}
