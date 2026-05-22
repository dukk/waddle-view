import { apiJson } from '@/api/client';
import type { SavedDisplay } from '@/storage/displays';
import { displayProxyFetch } from '@/api/displayProxy';

export type LivePreviewInfo = {
  configured: boolean;
  enabled: boolean;
  fps: number;
  width: number;
  quality: number;
  capture_backend?: string;
  capture_ready?: boolean;
};

export type LivePreviewSession = {
  ticket: string;
  expires_at_ms: number;
};

export async function fetchLivePreviewInfo(display: SavedDisplay): Promise<LivePreviewInfo> {
  return apiJson<LivePreviewInfo>(display, '/v1/display/live-preview');
}

export async function createLivePreviewSession(display: SavedDisplay): Promise<LivePreviewSession> {
  return apiJson<LivePreviewSession>(display, '/v1/display/live-preview/session', {
    method: 'POST',
    body: '{}',
  });
}

export async function putLivePreviewSettings(
  display: SavedDisplay,
  body: {
    display_live_preview_enabled?: boolean;
    display_live_preview_fps?: number;
    display_live_preview_width?: number;
    display_live_preview_quality?: number;
  },
): Promise<void> {
  await apiJson(display, '/v1/display/settings', {
    method: 'PUT',
    body: JSON.stringify(body),
  });
}

export async function createLivePreviewSessionForBaseUrl(
  baseUrl: string,
  displayId: string,
  authorization?: string,
): Promise<LivePreviewSession> {
  const res = await displayProxyFetch(
    '/v1/display/live-preview/session',
    {
      method: 'POST',
      body: '{}',
      headers: authorization ? { Authorization: authorization } : undefined,
    },
    {
      baseUrl,
      displayId,
      requireUrl: true,
      authorization,
    },
  );
  if (!res.ok) {
    const text = await res.text();
    throw new Error(text || `Session failed (${res.status})`);
  }
  return (await res.json()) as LivePreviewSession;
}
