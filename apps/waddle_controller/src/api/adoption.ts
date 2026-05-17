import { displayProxyFetch } from '@/api/displayProxy';
import { normalizeBaseUrl } from '@/storage/displays';
import type { DisplaySession } from '@/storage/sessions';
import { adoptionConnectErrorMessage } from '@/util/adoptionFetchError';
import { readProxyErrorMessage } from '@/util/proxyErrorBody';
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

export type AdoptionSessionInfo = {
  identifier: string;
  role: string;
  permissions: string[];
};

export async function requestAdoption(
  baseUrl: string,
  input: { identifier: string; role: string },
): Promise<AdoptionRequestResult> {
  const normalized = normalizeBaseUrl(baseUrl);
  adoptionLog('api.request.start', 'POST /v1/adoption/request', {
    url: normalized,
    identifier: input.identifier,
    role: input.role,
    expectedOrigin: expectedControllerOrigin(),
    note: 'Browser sends Origin and Referer on cross-origin fetch',
  });
  let res: Response;
  try {
    res = await displayProxyFetch(
      '/v1/adoption/request',
      {
        method: 'POST',
        headers: adoptionJsonHeaders(),
        body: JSON.stringify({ identifier: input.identifier, role: input.role }),
      },
      { baseUrl: normalized, requireUrl: true },
    );
  } catch (e) {
    throw new Error(adoptionConnectErrorMessage(normalized, e));
  }
  if (!res.ok) {
    const message = await readProxyErrorMessage(res, `Adoption request failed (${res.status})`);
    adoptionError('api.request.failed', 'adoption request rejected', {
      url: normalized,
      status: res.status,
      statusText: res.statusText,
      body: message.slice(0, 500),
    });
    throw new Error(message);
  }
  const result = (await res.json()) as AdoptionRequestResult;
  adoptionLog('api.request.success', 'challenge issued on kiosk', {
    url: normalized,
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
  adoptionLog('api.confirm.start', 'POST /v1/adoption/confirm', {
    url: normalized,
    identifier: input.identifier,
    challenge_code: input.challenge_code,
    expectedOrigin: expectedControllerOrigin(),
  });
  let res: Response;
  try {
    res = await displayProxyFetch(
      '/v1/adoption/confirm',
      {
        method: 'POST',
        headers: adoptionJsonHeaders(),
        body: JSON.stringify({
          identifier: input.identifier,
          challenge_code: input.challenge_code,
        }),
      },
      { baseUrl: normalized, requireUrl: true },
    );
  } catch (e) {
    throw new Error(adoptionConnectErrorMessage(normalized, e));
  }
  if (!res.ok) {
    const message = await readProxyErrorMessage(res, `Adoption confirm failed (${res.status})`);
    adoptionError('api.confirm.failed', 'adoption confirm rejected', {
      url: normalized,
      status: res.status,
      statusText: res.statusText,
      body: message.slice(0, 500),
    });
    throw new Error(message);
  }
  const result = (await res.json()) as AdoptionConfirmResult;
  adoptionLog('api.confirm.success', 'session issued', {
    url: normalized,
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
  adoptionLog('api.grant.start', 'POST /v1/adoption/request (admin grant)', {
    url: normalized,
    identifier: input.identifier,
    role: input.role,
    adminApiKey,
  });
  let res: Response;
  try {
    res = await displayProxyFetch(
      '/v1/adoption/request',
      {
        method: 'POST',
        headers: {
          ...adoptionJsonHeaders(),
          Authorization: `Bearer ${adminApiKey}`,
        },
        body: JSON.stringify({ identifier: input.identifier, role: input.role }),
      },
      { baseUrl: normalized, requireUrl: true },
    );
  } catch (e) {
    throw new Error(adoptionConnectErrorMessage(normalized, e));
  }
  if (!res.ok) {
    const message = await readProxyErrorMessage(res, `Adoption grant failed (${res.status})`);
    adoptionError('api.grant.failed', 'admin grant rejected', {
      url: normalized,
      status: res.status,
      body: message.slice(0, 500),
    });
    throw new Error(message);
  }
  const result = (await res.json()) as AdoptionConfirmResult;
  adoptionLog('api.grant.success', 'granted without challenge', {
    url: normalized,
    identifier: result.identifier,
    role: result.role,
    api_key: result.api_key,
  });
  return result;
}

export async function fetchAdoptionSession(
  baseUrl: string,
  apiKey: string,
): Promise<AdoptionSessionInfo> {
  const normalized = normalizeBaseUrl(baseUrl);
  const trimmedKey = apiKey.trim();
  adoptionLog('api.session.start', 'GET /v1/adoption/session', {
    url: normalized,
    apiKey: trimmedKey,
  });
  let res: Response;
  try {
    res = await displayProxyFetch(
      '/v1/adoption/session',
      {
        method: 'GET',
        headers: { Authorization: `Bearer ${trimmedKey}` },
      },
      { baseUrl: normalized, requireUrl: true },
    );
  } catch (e) {
    throw new Error(adoptionConnectErrorMessage(normalized, e));
  }
  if (!res.ok) {
    const message = await readProxyErrorMessage(res, `API key validation failed (${res.status})`);
    adoptionError('api.session.failed', 'session lookup rejected', {
      url: normalized,
      status: res.status,
      body: message.slice(0, 500),
    });
    throw new Error(message);
  }
  return (await res.json()) as AdoptionSessionInfo;
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
