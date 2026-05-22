import { PROXY_WS_PREFIX } from '@/constants/proxyHeaders';
import { sessionForDisplay } from '@/api/client';
import type { SavedDisplay } from '@/storage/displays';
import { normalizeBaseUrl } from '@/storage/displays';

export function proxyWsUrlForDisplayPath(
  displayPath: string,
  params: Record<string, string>,
): string {
  const path = displayPath.startsWith('/') ? displayPath : `/${displayPath}`;
  const search = new URLSearchParams(params).toString();
  const suffix = search ? `?${search}` : '';
  const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
  return `${protocol}//${window.location.host}${PROXY_WS_PREFIX}${path}${suffix}`;
}

/** Same-origin WebSocket URL for noVNC (Proxmox-style BFF proxy). */
export function buildRemoteViewWebSocketUrl(
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
  return proxyWsUrlForDisplayPath('/v1/display/remote-view/ws', params);
}

export const REMOTE_VIEW_TEST_STORAGE_KEY = 'waddle_remote_view_test';

export type RemoteViewTestPayload = {
  displayId: string;
  ticket: string;
  vncPassword?: string;
  baseUrl?: string;
};

export function storeRemoteViewTestPayload(payload: RemoteViewTestPayload): void {
  sessionStorage.setItem(REMOTE_VIEW_TEST_STORAGE_KEY, JSON.stringify(payload));
}

export function consumeRemoteViewTestPayload(
  displayId: string,
): RemoteViewTestPayload | null {
  const raw = sessionStorage.getItem(REMOTE_VIEW_TEST_STORAGE_KEY);
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw) as RemoteViewTestPayload;
    if (parsed.displayId !== displayId) return null;
    sessionStorage.removeItem(REMOTE_VIEW_TEST_STORAGE_KEY);
    return parsed;
  } catch {
    sessionStorage.removeItem(REMOTE_VIEW_TEST_STORAGE_KEY);
    return null;
  }
}
