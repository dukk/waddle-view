import type { SavedDisplay } from '@/storage/displays';

export class ApiError extends Error {
  constructor(
    message: string,
    public readonly status: number,
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

export async function apiFetch(
  display: SavedDisplay,
  path: string,
  init: RequestInit = {},
): Promise<Response> {
  const url = `${display.baseUrl}${path.startsWith('/') ? path : `/${path}`}`;
  const headers = new Headers(init.headers);
  headers.set('X-Api-Key', display.apiKey);
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

export async function apiJson<T>(display: SavedDisplay, path: string, init?: RequestInit): Promise<T> {
  const res = await apiFetch(display, path, init);
  return res.json() as Promise<T>;
}
