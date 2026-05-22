import {
  LIVE_PREVIEW_POP_OUT_DEFAULT_HEIGHT,
  LIVE_PREVIEW_POP_OUT_DEFAULT_WIDTH,
  loadLivePreviewPopOutBounds,
  type LivePreviewPopOutBounds,
} from '@/storage/livePreviewPopOutBounds';

export const LIVE_PREVIEW_POP_OUT_PATH = '/remote/view';

const POP_OUT_CHROME =
  'popup=yes,noopener,noreferrer,toolbar=no,location=no,menubar=no,status=no';

/** Best-effort popup chrome; browsers may still show a minimal address bar. */
export const LIVE_PREVIEW_POP_OUT_FEATURES = buildLivePreviewPopOutFeatures();

export function buildLivePreviewPopOutFeatures(
  bounds?: LivePreviewPopOutBounds | null,
): string {
  const stored = bounds ?? loadLivePreviewPopOutBounds();
  const width = stored?.width ?? LIVE_PREVIEW_POP_OUT_DEFAULT_WIDTH;
  const height = stored?.height ?? LIVE_PREVIEW_POP_OUT_DEFAULT_HEIGHT;
  const parts = [
    `width=${width}`,
    `height=${height}`,
    POP_OUT_CHROME,
  ];
  if (stored) {
    parts.unshift(`top=${stored.top}`, `left=${stored.left}`);
  }
  return parts.join(',');
}

export function buildLivePreviewPopOutUrl(
  params: { displayId: string; ticket: string },
  path = LIVE_PREVIEW_POP_OUT_PATH,
): string {
  const qs = new URLSearchParams({
    displayId: params.displayId,
    ticket: params.ticket,
  });
  return `${path}?${qs.toString()}`;
}

export function openLivePreviewPopOut(
  params: { displayId: string; ticket: string },
  path = LIVE_PREVIEW_POP_OUT_PATH,
): Window | null {
  const features = buildLivePreviewPopOutFeatures();
  return window.open(buildLivePreviewPopOutUrl(params, path), '_blank', features);
}
