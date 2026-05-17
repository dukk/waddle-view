import { normalizeBaseUrl } from '@/storage/displays';
import type { DisplaySession } from '@/storage/sessions';
import { adoptionError, adoptionLog } from '@/util/adoptionLog';

/** JSON headers for adoption POSTs; `Origin` and `Referer` are set by the browser. */
export function adoptionJsonHeaders(): Record<string, string> {
  return { 'Content-Type': 'application/json' };
}

export function expectedControllerOrigin(): string | null {
  return typeof window !== 'undefined' && window.location?.origin
    ? window.location.origin
    : null;
}

/** Challenge is shown on the kiosk only — not returned over HTTP. */
export type AdoptionRequestResult = {
  expires_at_ms: number;
  identifier: string;
  role: string;
};

export type AdoptionConfirmResult = {
  api_key: string;
  identifier: string;
  role: string;
  permissions: string[];
};

export async function requestAdoption(
  baseUrl: string,
  input: { identifier: string; role: string },
): Promise<AdoptionRequestResult> {
  const normalized = normalizeBaseUrl(baseUrl);
  const url = `${normalized}/v1/adoption/request`;
  const headers = adoptionJsonHeaders();
  adoptionLog('api.request.start', 'POST /v1/adoption/request', {
    url,
    identifier: input.identifier,
    role: input.role,
    expectedOrigin: expectedControllerOrigin(),
    note: 'Browser sends Origin and Referer on cross-origin fetch',
  });
  const res = await fetch(url, {
    method: 'POST',
    headers,
    referrerPolicy: 'origin',
    body: JSON.stringify({ identifier: input.identifier, role: input.role }),
  });
  if (!res.ok) {
    const text = await res.text().catch(() => '');
    adoptionError('api.request.failed', 'adoption request rejected', {
      url,
      status: res.status,
      statusText: res.statusText,
      body: text.slice(0, 500),
    });
    throw new Error(text || `Adoption request failed (${res.status})`);
  }
  const result = (await res.json()) as AdoptionRequestResult;
  adoptionLog('api.request.success', 'challenge issued on kiosk', {
    url,
    status: res.status,
    identifier: result.identifier,
    role: result.role,
    expires_at_ms: result.expires_at_ms,
  });
  return result;
}

export async function confirmAdoption(
  baseUrl: string,
  input: { identifier: string; challenge_code: string },
): Promise<AdoptionConfirmResult> {
  const normalized = normalizeBaseUrl(baseUrl);
  const url = `${normalized}/v1/adoption/confirm`;
  const headers = adoptionJsonHeaders();
  adoptionLog('api.confirm.start', 'POST /v1/adoption/confirm', {
    url,
    identifier: input.identifier,
    challenge_code: input.challenge_code,
    expectedOrigin: expectedControllerOrigin(),
  });
  const res = await fetch(url, {
    method: 'POST',
    headers,
    referrerPolicy: 'origin',
    body: JSON.stringify({
      identifier: input.identifier,
      challenge_code: input.challenge_code,
    }),
  });
  if (!res.ok) {
    const text = await res.text().catch(() => '');
    adoptionError('api.confirm.failed', 'adoption confirm rejected', {
      url,
      status: res.status,
      statusText: res.statusText,
      body: text.slice(0, 500),
    });
    throw new Error(text || `Adoption confirm failed (${res.status})`);
  }
  const result = (await res.json()) as AdoptionConfirmResult;
  adoptionLog('api.confirm.success', 'session issued', {
    url,
    status: res.status,
    identifier: result.identifier,
    role: result.role,
    permissionCount: result.permissions.length,
    api_key: result.api_key,
  });
  return result;
}

/** Admin bearer: instant API key for any role (no kiosk challenge). */
export async function grantAdoption(
  baseUrl: string,
  adminApiKey: string,
  input: { identifier: string; role: string },
): Promise<AdoptionConfirmResult> {
  const normalized = normalizeBaseUrl(baseUrl);
  const url = `${normalized}/v1/adoption/request`;
  adoptionLog('api.grant.start', 'POST /v1/adoption/request (admin grant)', {
    url,
    identifier: input.identifier,
    role: input.role,
    adminApiKey,
  });
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      ...adoptionJsonHeaders(),
      Authorization: `Bearer ${adminApiKey}`,
    },
    referrerPolicy: 'origin',
    body: JSON.stringify({ identifier: input.identifier, role: input.role }),
  });
  if (!res.ok) {
    const text = await res.text().catch(() => '');
    adoptionError('api.grant.failed', 'admin grant rejected', {
      url,
      status: res.status,
      body: text.slice(0, 500),
    });
    throw new Error(text || `Adoption grant failed (${res.status})`);
  }
  const result = (await res.json()) as AdoptionConfirmResult;
  adoptionLog('api.grant.success', 'granted without challenge', {
    url,
    identifier: result.identifier,
    role: result.role,
    api_key: result.api_key,
  });
  return result;
}

export function sessionFromAdoption(
  baseUrl: string,
  result: AdoptionConfirmResult,
): DisplaySession {
  const session: DisplaySession = {
    apiKey: result.api_key,
    identifier: result.identifier,
    role: result.role,
    permissions: result.permissions,
    expiresAtMs: Date.now() + 365 * 24 * 60 * 60 * 1000,
  };
  adoptionLog('session.fromAdoption', 'built display session', {
    baseUrl: normalizeBaseUrl(baseUrl),
    identifier: session.identifier,
    role: session.role,
    permissionCount: session.permissions.length,
    expiresAtMs: session.expiresAtMs,
    apiKey: session.apiKey,
  });
  return session;
}
