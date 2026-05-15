import type { SavedDisplay } from '@/storage/displays';
import { loadSession, type DisplaySession } from '@/storage/sessions';

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

export async function apiFetch(
  display: SavedDisplay,
  path: string,
  init: RequestInit = {},
): Promise<Response> {
  const session = loadSession(display.id);
  if (!session) {
    throw new ApiError('Not signed in', 401);
  }
  const url = `${display.baseUrl}${path.startsWith('/') ? path : `/${path}`}`;
  const headers = new Headers(init.headers);
  headers.set('Authorization', `Bearer ${session.token}`);
  if (init.body && !headers.has('Content-Type')) {
    headers.set('Content-Type', 'application/json');
  }
  const res = await fetch(url, { ...init, headers });
  if (!res.ok) {
    const text = await res.text().catch(() => '');
    throw new ApiError(text || res.statusText, res.status);
  }
  return res;
}

export async function apiJson<T>(
  display: SavedDisplay,
  path: string,
  init?: RequestInit,
): Promise<T> {
  const res = await apiFetch(display, path, init);
  return res.json() as Promise<T>;
}

export function hasPermission(session: DisplaySession | null, perm: string): boolean {
  return session?.permissions.includes(perm) ?? false;
}
