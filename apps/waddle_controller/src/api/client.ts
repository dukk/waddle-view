import { isDisplayProxyAuthEnabled } from '@/api/displayAuthMode';
import { displayProxyFetch } from '@/api/displayProxy';
import type { SavedDisplay } from '@/storage/displays';
import { loadSession, type DisplaySession } from '@/storage/sessions';
import { readProxyErrorMessage } from '@/util/proxyErrorBody';

export class ApiError extends Error {
  constructor(
    message: string,
    public readonly status: number,
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

export function sessionForDisplay(display: SavedDisplay): DisplaySession | null {
  return loadSession(display.id);
}

export type ApiFetchOptions = {
  /** When true, omit URL header so BFF resolves from user_displays (auth mode). */
  omitUrlForAuth?: boolean;
};

export async function apiFetch(
  display: SavedDisplay,
  path: string,
  init: RequestInit = {},
  options: ApiFetchOptions = {},
): Promise<Response> {
  const session = loadSession(display.id);
  const authMode = isDisplayProxyAuthEnabled();
  if (!session && !authMode) {
    throw new ApiError('Not signed in', 401);
  }
  const res = await displayProxyFetch(
    path.startsWith('/') ? path : `/${path}`,
    init,
    {
      display,
      authorization: session ? `Bearer ${session.apiKey}` : undefined,
      omitUrlWhenAuth: options.omitUrlForAuth ?? authMode,
    },
  );
  if (!res.ok) {
    const message = await readProxyErrorMessage(res);
    throw new ApiError(message, res.status);
  }
  return res;
}

/** Loads a blob from `GET /v1/media/blob-by-key` into an object URL (revoke when done). */
export async function fetchBlobObjectUrl(
  display: SavedDisplay,
  blobKey: string,
  options: ApiFetchOptions = {},
): Promise<string | null> {
  const session = loadSession(display.id);
  const authMode = isDisplayProxyAuthEnabled();
  if (!session && !authMode) {
    return null;
  }
  const path = `/v1/media/blob-by-key?key=${encodeURIComponent(blobKey)}`;
  const res = await displayProxyFetch(
    path,
    {
      method: 'GET',
      headers: session ? { Authorization: `Bearer ${session.apiKey}` } : undefined,
    },
    {
      display,
      omitUrlWhenAuth: options.omitUrlForAuth ?? authMode,
    },
  );
  if (!res.ok) {
    return null;
  }
  const buf = await res.arrayBuffer();
  const mime = res.headers.get('content-type') ?? 'application/octet-stream';
  return URL.createObjectURL(new Blob([buf], { type: mime }));
}

export async function apiJson<T>(
  display: SavedDisplay,
  path: string,
  init?: RequestInit,
  options?: ApiFetchOptions,
): Promise<T> {
  const res = await apiFetch(display, path, init, options);
  return res.json() as Promise<T>;
}

export function hasPermission(session: DisplaySession | null, perm: string): boolean {
  return session?.permissions.includes(perm) ?? false;
}
