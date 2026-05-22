import { proxyWsUrlForDisplayPath } from '@/util/remoteViewWsUrl';
import { sessionForDisplay } from '@/api/client';
import type { SavedDisplay } from '@/storage/displays';
import { normalizeBaseUrl } from '@/storage/displays';

/** Same-origin WebSocket URL for in-app live preview (JPEG frames). */
export function buildLivePreviewWebSocketUrl(
  display: SavedDisplay,
  ticket: string,
  options?: { baseUrlOverride?: string },
): string {
  const params: Record<string, string> = {
    ticket,
    display_id: display.id,
  };
  const session = sessionForDisplay(display);
  if (session?.apiKey) {
    params.authorization = `Bearer ${session.apiKey}`;
  }
  const baseUrl = options?.baseUrlOverride ?? display.baseUrl;
  if (baseUrl.trim()) {
    params.display_url = normalizeBaseUrl(baseUrl);
  }
  return proxyWsUrlForDisplayPath('/v1/display/live-preview/ws', params);
}

export const LIVE_PREVIEW_TEST_STORAGE_KEY = 'waddle_live_preview_test';

export type LivePreviewTestPayload = {
  displayId: string;
  ticket: string;
  baseUrl?: string;
};

export function storeLivePreviewTestPayload(payload: LivePreviewTestPayload): void {
  sessionStorage.setItem(LIVE_PREVIEW_TEST_STORAGE_KEY, JSON.stringify(payload));
}

export function consumeLivePreviewTestPayload(
  displayId: string,
): LivePreviewTestPayload | null {
  const raw = sessionStorage.getItem(LIVE_PREVIEW_TEST_STORAGE_KEY);
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw) as LivePreviewTestPayload;
    if (parsed.displayId !== displayId) return null;
    sessionStorage.removeItem(LIVE_PREVIEW_TEST_STORAGE_KEY);
    return parsed;
  } catch {
    sessionStorage.removeItem(LIVE_PREVIEW_TEST_STORAGE_KEY);
    return null;
  }
}
