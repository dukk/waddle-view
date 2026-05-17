const BFF_PREFIX = '/bff/v1';

export class BffError extends Error {
  constructor(
    message: string,
    public readonly status: number,
    public readonly code?: string,
  ) {
    super(message);
    this.name = 'BffError';
  }
}

export async function bffFetch(path: string, init: RequestInit = {}): Promise<Response> {
  const url = `${BFF_PREFIX}${path.startsWith('/') ? path : `/${path}`}`;
  const headers = new Headers(init.headers);
  if (init.body && !headers.has('Content-Type')) {
    headers.set('Content-Type', 'application/json');
  }
  const res = await fetch(url, { ...init, headers, credentials: 'include' });
  if (!res.ok) {
    let message = res.statusText;
    let code: string | undefined;
    try {
      const body = (await res.json()) as { error?: string; code?: string };
      message = body.error ?? message;
      code = body.code;
    } catch {
      const text = await res.text().catch(() => '');
      if (text) message = text;
    }
    throw new BffError(message, res.status, code);
  }
  return res;
}

export async function bffJson<T>(path: string, init: RequestInit = {}): Promise<T> {
  const res = await bffFetch(path, init);
  return (await res.json()) as T;
}
