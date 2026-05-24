import type { IncomingMessage } from 'node:http';
import WebSocket from 'ws';
import type { AppConfig } from '../config.js';
import type { AppDatabase } from '../db/database.js';
import {
  DISPLAY_ID_HEADER,
  DISPLAY_URL_HEADER,
} from '../constants/proxyHeaders.js';
import type { PublicUser } from '../types.js';
import {
  resolveProxyTarget,
  upstreamPathFromProxyRequest,
} from './displayProxy.js';

const WS_AUTH_QUERY = 'authorization';

export function upstreamPathFromProxyWsRequest(pathname: string): string {
  return upstreamPathFromProxyRequest(pathname.replace('/proxy-ws', '/proxy'));
}

export function headersFromWebSocketUpgrade(request: IncomingMessage): Headers {
  const headers = new Headers();
  const url = new URL(request.url ?? '/', 'http://localhost');
  const displayId = url.searchParams.get('display_id')?.trim();
  const displayUrl = url.searchParams.get('display_url')?.trim();
  const authorization = url.searchParams.get(WS_AUTH_QUERY)?.trim();
  if (displayId) headers.set(DISPLAY_ID_HEADER, displayId);
  if (displayUrl) headers.set(DISPLAY_URL_HEADER, displayUrl);
  if (authorization) headers.set('Authorization', authorization);
  const cookie = request.headers.cookie;
  if (cookie) headers.set('Cookie', cookie);
  return headers;
}

export function displayWebSocketUrl(
  upstreamBase: string,
  proxyPath: string,
  query: string,
): string {
  const base = upstreamBase.replace(/\/+$/, '');
  const path = proxyPath.startsWith('/') ? proxyPath : `/${proxyPath}`;
  const q = query.startsWith('?') ? query : query ? `?${query}` : '';
  const httpUrl = `${base}${path}${q}`;
  if (httpUrl.startsWith('https://')) {
    return `wss://${httpUrl.slice('https://'.length)}`;
  }
  if (httpUrl.startsWith('http://')) {
    return `ws://${httpUrl.slice('http://'.length)}`;
  }
  return httpUrl;
}

export type ProxyWsResolveResult =
  | { ok: true; upstreamWsUrl: string; authorization?: string }
  | { ok: false; status: number; code: string; error: string };

export async function resolveProxyWebSocketTarget(
  config: AppConfig,
  db: AppDatabase,
  user: PublicUser | null,
  request: IncomingMessage,
): Promise<ProxyWsResolveResult> {
  const url = new URL(request.url ?? '/', 'http://localhost');
  const proxyPath = upstreamPathFromProxyWsRequest(url.pathname);
  const headers = headersFromWebSocketUpgrade(request);
  const resolved = await resolveProxyTarget(config, db, user, proxyPath, headers);
  if (!resolved.ok) {
    return resolved;
  }
  const ticket = url.searchParams.get('ticket')?.trim() ?? '';
  if (!ticket) {
    return {
      ok: false,
      status: 400,
      code: 'ticket_required',
      error: 'ticket query parameter is required',
    };
  }
  const upstreamQuery = new URLSearchParams({ ticket });
  const upstreamWsUrl = displayWebSocketUrl(
    resolved.upstreamUrl,
    proxyPath,
    upstreamQuery.toString(),
  );
  return { ok: true, upstreamWsUrl, authorization: resolved.authorization };
}

export async function pipeDisplayWebSocketProxy(
  config: AppConfig,
  db: AppDatabase,
  user: PublicUser | null,
  clientWs: WebSocket,
  request: IncomingMessage,
): Promise<void> {
  const resolved = await resolveProxyWebSocketTarget(config, db, user, request);
  if (!resolved.ok) {
    clientWs.close(1008, resolved.error);
    return;
  }

  const upstreamHeaders: Record<string, string> = {};
  if (resolved.authorization) {
    upstreamHeaders.Authorization = resolved.authorization;
  }

  const upstream = new WebSocket(resolved.upstreamWsUrl, {
    headers: upstreamHeaders,
    rejectUnauthorized: false,
  });

  const closeBoth = (code?: number, reason?: string) => {
    try {
      if (clientWs.readyState === WebSocket.OPEN) {
        clientWs.close(code ?? 1000, reason);
      }
    } catch {
      /* ignore */
    }
    try {
      if (upstream.readyState === WebSocket.OPEN) {
        upstream.close(code ?? 1000, reason);
      }
    } catch {
      /* ignore */
    }
  };

  upstream.on('open', () => {
    clientWs.on('message', (data: WebSocket.RawData, isBinary: boolean) => {
      if (upstream.readyState === WebSocket.OPEN) {
        upstream.send(data, { binary: isBinary });
      }
    });
    upstream.on('message', (data: WebSocket.RawData, isBinary: boolean) => {
      if (clientWs.readyState === WebSocket.OPEN) {
        clientWs.send(data, { binary: isBinary });
      }
    });
  });

  upstream.on('error', () => closeBoth(1011, 'upstream_error'));
  clientWs.on('error', () => closeBoth(1011, 'client_error'));
  upstream.on('close', (code: number, reason: Buffer) => {
    if (clientWs.readyState === WebSocket.OPEN) {
      clientWs.close(code, reason);
    }
  });
  clientWs.on('close', () => {
    if (upstream.readyState === WebSocket.OPEN) {
      upstream.close();
    }
  });
}
