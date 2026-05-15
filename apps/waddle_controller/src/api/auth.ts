import type { DisplaySession } from '@/storage/sessions';
import { normalizeBaseUrl } from '@/storage/displays';

export type LoginResult = DisplaySession & { baseUrl: string };

export async function loginDisplay(
  baseUrl: string,
  username: string,
  password: string,
): Promise<LoginResult> {
  const url = `${normalizeBaseUrl(baseUrl)}/v1/auth/login`;
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username, password }),
  });
  if (!res.ok) {
    const text = await res.text().catch(() => '');
    throw new Error(text || `Login failed (${res.status})`);
  }
  const body = (await res.json()) as {
    session_token: string;
    expires_at_ms: number;
    user: DisplaySession['user'];
    permissions: string[];
    warnings: string[];
  };
  return {
    baseUrl: normalizeBaseUrl(baseUrl),
    token: body.session_token,
    expiresAtMs: body.expires_at_ms,
    user: body.user,
    permissions: body.permissions,
    warnings: body.warnings ?? [],
  };
}

export async function fetchMe(
  baseUrl: string,
  token: string,
): Promise<Omit<DisplaySession, 'token'>> {
  const res = await fetch(`${normalizeBaseUrl(baseUrl)}/v1/auth/me`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!res.ok) {
    throw new Error(`Session invalid (${res.status})`);
  }
  const body = (await res.json()) as {
    user: DisplaySession['user'];
    permissions: string[];
    warnings: string[];
  };
  return {
    expiresAtMs: Date.now() + 7 * 24 * 60 * 60 * 1000,
    user: body.user,
    permissions: body.permissions,
    warnings: body.warnings ?? [],
  };
}

export async function logoutDisplay(baseUrl: string, token: string): Promise<void> {
  await fetch(`${normalizeBaseUrl(baseUrl)}/v1/auth/logout`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` },
  }).catch(() => undefined);
}
