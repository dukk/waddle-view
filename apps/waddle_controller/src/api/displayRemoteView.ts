import { apiFetch, apiJson } from '@/api/client';
import type { SavedDisplay } from '@/storage/displays';
import { displayProxyFetch } from '@/api/displayProxy';

export type RemoteViewInfo = {
  configured: boolean;
  enabled: boolean;
  host: string;
  port: number;
  path: string;
  password_configured: boolean;
};

export type RemoteViewSession = {
  ticket: string;
  expires_at_ms: number;
};

export async function fetchRemoteViewInfo(display: SavedDisplay): Promise<RemoteViewInfo> {
  return apiJson<RemoteViewInfo>(display, '/v1/display/remote-view');
}

export async function createRemoteViewSession(display: SavedDisplay): Promise<RemoteViewSession> {
  return apiJson<RemoteViewSession>(display, '/v1/display/remote-view/session', {
    method: 'POST',
    body: '{}',
  });
}

export async function putRemoteViewPassword(
  display: SavedDisplay,
  password: string,
): Promise<void> {
  await apiFetch(display, '/v1/display/remote-view/password', {
    method: 'PUT',
    body: JSON.stringify({ value: password }),
  });
}

export async function deleteRemoteViewPassword(display: SavedDisplay): Promise<void> {
  await apiFetch(display, '/v1/display/remote-view/password', {
    method: 'DELETE',
  });
}

/** Settings fields are persisted via PUT /v1/display/settings (see DisplaySettings). */
export async function putRemoteViewSettings(
  display: SavedDisplay,
  body: {
    display_remote_view_enabled?: boolean;
    display_remote_view_host?: string;
    display_remote_view_port?: number;
    display_remote_view_path?: string;
  },
): Promise<void> {
  await apiJson(display, '/v1/display/settings', {
    method: 'PUT',
    body: JSON.stringify(body),
  });
}

/** Test connection using arbitrary base URL before save (adoption-style URL header). */
export async function createRemoteViewSessionForBaseUrl(
  baseUrl: string,
  displayId: string,
  authorization?: string,
): Promise<RemoteViewSession> {
  const res = await displayProxyFetch(
    '/v1/display/remote-view/session',
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
  return (await res.json()) as RemoteViewSession;
}
