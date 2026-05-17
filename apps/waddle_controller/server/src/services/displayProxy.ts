import type { AppConfig } from '../config.js';
import { DisplayUpstreamError, insecureNodeFetch } from './insecureFetch.js';
import type { AppDatabase } from '../db/database.js';
import type { PublicUser } from '../types.js';
import {
  DISPLAY_ID_HEADER,
  DISPLAY_URL_HEADER,
  isAdoptionProxyPath,
  normalizeDisplayBaseUrl,
  shouldStripUpstreamHeader,
  validateProxyTargetScheme,
} from '../constants/proxyHeaders.js';
import {
  findActiveUserDisplay,
  findUserDisplayByBaseUrl,
  findUserDisplayByDisplayId,
  getDecryptedApiKey,
  userDisplayBaseUrlMatches,
  type UserDisplayRow,
} from './userDisplays.js';

const RESPONSE_HEADER_ALLOW = new Set([
  'content-type',
  'content-length',
  'cache-control',
  'etag',
  'last-modified',
  'content-disposition',
  'accept-ranges',
]);

export type ProxyResolveResult =
  | { ok: true; upstreamUrl: string; authorization?: string }
  | { ok: false; status: number; code: string; error: string };

export function upstreamPathFromProxyRequest(pathname: string): string {
  const prefix = '/proxy';
  const idx = pathname.indexOf(prefix);
  if (idx < 0) return pathname;
  const rest = pathname.slice(idx + prefix.length);
  return rest.length > 0 ? rest : '/';
}

function validateTargetUrl(
  url: string,
): { ok: true; upstreamUrl: string } | Extract<ProxyResolveResult, { ok: false }> {
  try {
    const parsed = new URL(normalizeDisplayBaseUrl(url));
    if (!validateProxyTargetScheme(parsed)) {
      return {
        ok: false,
        status: 400,
        code: 'invalid_display_url',
        error: 'Only http and https display URLs are allowed',
      };
    }
    return { ok: true, upstreamUrl: normalizeDisplayBaseUrl(parsed.href) };
  } catch {
    return {
      ok: false,
      status: 400,
      code: 'invalid_display_url',
      error: 'Invalid display URL',
    };
  }
}

function fail(
  status: number,
  code: string,
  error: string,
): Extract<ProxyResolveResult, { ok: false }> {
  return { ok: false, status, code, error };
}

function resolveRowForAuth(
  db: AppDatabase,
  userId: string,
  displayId: string,
  urlHeader: string,
): UserDisplayRow | null {
  if (displayId) {
    const byId = findUserDisplayByDisplayId(db, userId, displayId);
    if (byId) return byId;
  }
  if (urlHeader) {
    return findUserDisplayByBaseUrl(db, userId, urlHeader);
  }
  return findActiveUserDisplay(db, userId);
}

export function resolveProxyTarget(
  config: AppConfig,
  db: AppDatabase,
  user: PublicUser | null,
  proxyPath: string,
  headers: Headers,
): ProxyResolveResult {
  const adoption = isAdoptionProxyPath(proxyPath);
  const urlHeader = headers.get(DISPLAY_URL_HEADER)?.trim() ?? '';
  const displayId = headers.get(DISPLAY_ID_HEADER)?.trim() ?? '';

  if (adoption) {
    if (!urlHeader) {
      return fail(400, 'display_url_required', 'X-Waddle-Display-Url is required for adoption');
    }
    const validated = validateTargetUrl(urlHeader);
    if (!validated.ok) return validated;
    return { ok: true, upstreamUrl: validated.upstreamUrl };
  }

  if (!urlHeader && !displayId && !config.authEnabled) {
    return fail(400, 'display_url_required', 'X-Waddle-Display-Url is required');
  }

  if (config.authEnabled) {
    if (!user) {
      return fail(401, 'unauthorized', 'Unauthorized');
    }
    if (!urlHeader && !displayId) {
      const active = findActiveUserDisplay(db, user.id);
      if (!active) {
        return fail(400, 'display_target_required', 'Display URL or id required');
      }
      const validated = validateTargetUrl(active.base_url);
      if (!validated.ok) return validated;
      const authorization =
        headers.get('Authorization') ??
        `Bearer ${getDecryptedApiKey(config.sessionSecret, active)}`;
      return { ok: true, upstreamUrl: validated.upstreamUrl, authorization };
    }

    const row = resolveRowForAuth(db, user.id, displayId, urlHeader);
    const baseUrl = urlHeader || row?.base_url;
    if (!baseUrl) {
      return fail(400, 'display_target_required', 'Display URL or id required');
    }
    const validated = validateTargetUrl(baseUrl);
    if (!validated.ok) return validated;
    if (!row) {
      return fail(403, 'display_not_registered', 'Display is not registered for this user');
    }
    if (urlHeader && !userDisplayBaseUrlMatches(row, urlHeader)) {
      return fail(403, 'display_url_mismatch', 'Display URL does not match saved display');
    }
    const authorization =
      headers.get('Authorization') ?? `Bearer ${getDecryptedApiKey(config.sessionSecret, row)}`;
    return { ok: true, upstreamUrl: validated.upstreamUrl, authorization };
  }

  if (!urlHeader) {
    return fail(400, 'display_url_required', 'X-Waddle-Display-Url is required');
  }
  const validated = validateTargetUrl(urlHeader);
  if (!validated.ok) return validated;
  const authorization = headers.get('Authorization') ?? undefined;
  return { ok: true, upstreamUrl: validated.upstreamUrl, authorization };
}

function buildUpstreamHeaders(incoming: Headers, authorization?: string): Headers {
  const out = new Headers();
  incoming.forEach((value, key) => {
    if (shouldStripUpstreamHeader(key)) return;
    out.set(key, value);
  });
  if (authorization) {
    out.set('Authorization', authorization);
  }
  return out;
}

export async function forwardDisplayProxy(
  config: AppConfig,
  db: AppDatabase,
  user: PublicUser | null,
  request: Request,
  proxyPath: string,
): Promise<Response> {
  const resolved = resolveProxyTarget(config, db, user, proxyPath, request.headers);
  if (!resolved.ok) {
    return Response.json(
      { error: resolved.error, code: resolved.code },
      { status: resolved.status },
    );
  }
  const upstreamBase = resolved.upstreamUrl;
  const query = new URL(request.url).search;
  const upstreamUrl = `${upstreamBase}${proxyPath}${query}`;

  const method = request.method;
  const hasBody = method !== 'GET' && method !== 'HEAD';
  const headers = buildUpstreamHeaders(request.headers, resolved.authorization);
  const body = hasBody ? await request.arrayBuffer() : undefined;

  try {
    const upstream = await insecureNodeFetch(upstreamUrl, {
      method,
      headers,
      body: body && body.byteLength > 0 ? body : undefined,
    });

    const responseHeaders = new Headers();
    upstream.headers.forEach((value, key) => {
      if (RESPONSE_HEADER_ALLOW.has(key.toLowerCase())) {
        responseHeaders.set(key, value);
      }
    });

    return new Response(upstream.body, {
      status: upstream.status,
      statusText: upstream.statusText,
      headers: responseHeaders,
    });
  } catch (e) {
    const err =
      e instanceof DisplayUpstreamError
        ? e
        : new DisplayUpstreamError(
            `Could not reach the display at ${upstreamBase}.`,
            'display_unreachable',
            upstreamBase,
            { cause: e },
          );
    return Response.json({ error: err.message, code: err.code }, { status: 502 });
  }
}
